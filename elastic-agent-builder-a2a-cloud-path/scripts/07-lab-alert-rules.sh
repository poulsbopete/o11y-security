#!/usr/bin/env bash
# Create (or update) **Elasticsearch query** rules on each Serverless Kibana so you get
# **real Kibana alerts** from existing workshop indices — without needing new ingest.
# ES|QL or Dev Tools queries alone do not create alerting alerts.
#
# **Consumer choice (important):**
# - **Observability** Kibana rules use `consumer: observability` so matches show under
#   **Observability → Alerts** (not only Stack Management).
# - **Security** Kibana rules use `consumer: alerts` (this stack’s `.es-query` type does not
#   authorize `securitySolution` here) so they are easier to find than `stackAlerts`-only.
#
# If an existing lab rule still uses an old consumer, this script **deletes and recreates**
# that rule id (re-run **06** then **07** so the Workflow action is re-applied).
#
# When **state/kibana-workflows-lab.json** exists (from **scripts/06-kibana-workflows-lab.sh**), this
# script **attaches** the lab **alert console** workflow to each rule via the alerting API using the
# system connector id **system-connector-.workflows** (same as the Kibana UI). Run **06** before **07**
# on first install. Skip attachment only: **A2A_SKIP_ATTACH_WORKFLOW_RULE_ACTIONS=1**.
#
# Requires: curl, jq, bash, state/bootstrap.json.
# Skip: A2A_SKIP_LAB_ALERT_RULES=1
#
# Rule check interval: **A2A_LAB_RULE_INTERVAL** (default **5m**) — lowers alert + Case noise vs 1m.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

CURL="${CURL:-/usr/bin/curl}"
BOOT="$ROOT/state/bootstrap.json"
WF_STATE="$ROOT/state/kibana-workflows-lab.json"

load_dotenv "$ROOT/.env"

LAB_RULE_INTERVAL="${A2A_LAB_RULE_INTERVAL:-5m}"

if [ "${A2A_SKIP_LAB_ALERT_RULES:-0}" = "1" ]; then
  echo "Skipping lab alert rules (A2A_SKIP_LAB_ALERT_RULES=1)."
  exit 0
fi

if [ ! -f "$BOOT" ]; then
  echo "Missing ${BOOT} — run provisioning first." >&2
  exit 1
fi

require_cmds "$CURL" jq

rule_json() {
  local name="$1" index_json="$2" es_query_json="$3" consumer="${4:-stackAlerts}"
  jq -n \
    --arg name "$name" \
    --arg consumer "$consumer" \
    --arg interval "$LAB_RULE_INTERVAL" \
    --argjson index "$index_json" \
    --arg esQuery "$es_query_json" \
    '{
      name: $name,
      rule_type_id: ".es-query",
      consumer: $consumer,
      schedule: {interval: $interval},
      params: {
        index: $index,
        timeField: "@timestamp",
        esQuery: $esQuery,
        threshold: [1],
        thresholdComparator: ">=",
        timeWindowSize: 24,
        timeWindowUnit: "h",
        size: 100
      },
      actions: [],
      tags: ["a2a-lab"],
      enabled: true
    }'
}

rule_put_body() {
  local name="$1" index_json="$2" es_query_json="$3"
  # PUT /api/alerting/rule/{id} rejects some fields allowed on POST (e.g. enabled on Serverless).
  jq -n \
    --arg name "$name" \
    --arg interval "$LAB_RULE_INTERVAL" \
    --argjson index "$index_json" \
    --arg esQuery "$es_query_json" \
    '{
      name: $name,
      schedule: {interval: $interval},
      params: {
        index: $index,
        timeField: "@timestamp",
        esQuery: $esQuery,
        threshold: [1],
        thresholdComparator: ">=",
        timeWindowSize: 24,
        timeWindowUnit: "h",
        size: 100
      },
      actions: [],
      tags: ["a2a-lab"]
    }'
}

# Merge **A2A Lab — … alert log / alert audit (console)** workflow onto a rule (Kibana system connector).
attach_alert_console_workflow_to_rule() {
  local base="$1" user="$2" pass="$3" rule_id="$4" wf_id="$5"
  local get_code put_code tmp wa_json

  if [ "${A2A_SKIP_ATTACH_WORKFLOW_RULE_ACTIONS:-0}" = "1" ]; then
    return 0
  fi
  if [ -z "$wf_id" ] || [ "$wf_id" = "null" ]; then
    return 0
  fi

  tmp="$(mktemp)"
  wa_json="$(jq -n --arg wf "$wf_id" '{
    group: "query matched",
    id: "system-connector-.workflows",
    params: {
      subAction: "run",
      subActionParams: {
        workflowId: $wf,
        summaryMode: true,
        alertStates: {new: true, ongoing: true, recovered: false}
      }
    },
    frequency: {summary: false, notify_when: "onActiveAlert"}
  }')"

  get_code="$("$CURL" -sS -o "$tmp" -w "%{http_code}" -u "${user}:${pass}" \
    -H "kbn-xsrf: true" "${base%/}/api/alerting/rule/${rule_id}")" || true
  if [ "$get_code" != "200" ]; then
    echo "  WARN: could not GET rule ${rule_id} to attach workflow (HTTP ${get_code})." >&2
    rm -f "$tmp"
    return 0
  fi

  jq --argjson wa "$wa_json" '
    . as $r
    | {
        name: $r.name,
        schedule: $r.schedule,
        params: $r.params,
        actions: (($r.actions // []) | map(select(.id != "system-connector-.workflows")) + [$wa]),
        tags: $r.tags,
        throttle: $r.throttle,
        notify_when: $r.notify_when
      }
  ' "$tmp" >"${tmp}.put"

  put_code="$("$CURL" -sS -o /tmp/ar-wf-put.json -w "%{http_code}" -u "${user}:${pass}" \
    -H "kbn-xsrf: true" -H "Content-Type: application/json" \
    -X PUT "${base%/}/api/alerting/rule/${rule_id}" -d @"${tmp}.put")" || true
  rm -f "$tmp" "${tmp}.put"

  if [ "$put_code" = "200" ]; then
    echo "  Attached lab Workflow (alert console) to ${rule_id}"
    return 0
  fi
  echo "  WARN: attach Workflow to ${rule_id} failed HTTP ${put_code} (run **06** first, or attach in UI)." >&2
  head -c 600 /tmp/ar-wf-put.json >&2 || true
  echo >&2
  return 0
}

upsert_rule() {
  local base="$1" user="$2" pass="$3" rule_id="$4" post_body="$5" put_body="$6" wf_id="${7:-}"
  local code
  code="$("$CURL" -sS -o /tmp/ar.json -w "%{http_code}" -u "${user}:${pass}" \
    -H "kbn-xsrf: true" -H "Content-Type: application/json" \
    -X POST "${base%/}/api/alerting/rule/${rule_id}" -d "$post_body")" || true
  if [ "$code" = "200" ]; then
    echo "  POST rule ${rule_id} (created)"
    attach_alert_console_workflow_to_rule "$base" "$user" "$pass" "$rule_id" "$wf_id"
    return 0
  fi
  if [ "$code" = "409" ]; then
    code="$("$CURL" -sS -o /tmp/ar.json -w "%{http_code}" -u "${user}:${pass}" \
      -H "kbn-xsrf: true" -H "Content-Type: application/json" \
      -X PUT "${base%/}/api/alerting/rule/${rule_id}" -d "$put_body")" || true
    if [ "$code" = "200" ]; then
      echo "  PUT rule ${rule_id} (updated)"
      attach_alert_console_workflow_to_rule "$base" "$user" "$pass" "$rule_id" "$wf_id"
      return 0
    fi
    echo "PUT ${rule_id} failed HTTP ${code}" >&2
    cat /tmp/ar.json >&2 || true
    return 1
  fi
  echo "POST ${rule_id} failed HTTP ${code}" >&2
  cat /tmp/ar.json >&2 || true
  return 1
}

# `consumer` is immutable on PUT — delete the saved rule if it exists with a different consumer.
rule_recreate_if_consumer_mismatch() {
  local base="$1" user="$2" pass="$3" rule_id="$4" want_consumer="$5"
  local code cur
  code="$("$CURL" -sS -o /tmp/gr.json -w "%{http_code}" -u "${user}:${pass}" \
    -H "kbn-xsrf: true" "${base%/}/api/alerting/rule/${rule_id}")" || true
  if [ "$code" != "200" ]; then
    return 0
  fi
  cur="$(jq -r '.consumer // empty' /tmp/gr.json)"
  if [ -z "$cur" ] || [ "$cur" = "$want_consumer" ]; then
    return 0
  fi
  echo "  WARN: ${rule_id} had consumer=${cur}; deleting so it can be recreated as ${want_consumer} (re-run **07** after **06** to re-attach the lab Workflow action)."
  code="$("$CURL" -sS -o /tmp/dr.json -w "%{http_code}" -u "${user}:${pass}" \
    -H "kbn-xsrf: true" -X DELETE "${base%/}/api/alerting/rule/${rule_id}")" || true
  if [ "$code" != "200" ] && [ "$code" != "204" ]; then
    echo "  DELETE ${rule_id} failed HTTP ${code}" >&2
    cat /tmp/dr.json >&2 || true
    return 1
  fi
}

sec_kb="$(jq -r '.security.endpoints.kibana // empty' "$BOOT")"
sec_user="$(jq -r '.security.credentials.username // empty' "$BOOT")"
sec_pass="$(jq -r '.security.credentials.password // empty' "$BOOT")"
o11y_kb="$(jq -r '.observability.endpoints.kibana // empty' "$BOOT")"
o11y_user="$(jq -r '.observability.credentials.username // empty' "$BOOT")"
o11y_pass="$(jq -r '.observability.credentials.password // empty' "$BOOT")"

if [ -z "$sec_kb" ] || [ -z "$sec_user" ] || [ -z "$sec_pass" ]; then
  echo "Missing Security Kibana URL or credentials in bootstrap.json." >&2
  exit 1
fi
if [ -z "$o11y_kb" ] || [ -z "$o11y_user" ] || [ -z "$o11y_pass" ]; then
  echo "Missing Observability Kibana URL or credentials in bootstrap.json." >&2
  exit 1
fi

MATCH_ALL="$(jq -n -c '{query:{match_all:{}}}')"

wf_sec=""
wf_o11y=""
if [ -f "$WF_STATE" ]; then
  wf_sec="$(jq -r '.security.alert_console // empty' "$WF_STATE")"
  wf_o11y="$(jq -r '.observability.alert_console // empty' "$WF_STATE")"
  if [ -z "$wf_sec" ] || [ -z "$wf_o11y" ]; then
    echo "Note: ${WF_STATE} missing alert_console ids — run **06** before **07** to auto-attach Workflow actions." >&2
  fi
else
  echo "Note: no ${WF_STATE} — run **06** then re-run **07** to attach **A2A Lab** alert console workflows to rules." >&2
fi

echo "== Lab alert rules: Security Kibana =="
rule_recreate_if_consumer_mismatch "$sec_kb" "$sec_user" "$sec_pass" "a2a-lab-rule-security-endpoint-hits" "alerts"
POST_S="$(rule_json "A2A Lab — workshop data (endpoint alerts)" "$(jq -n '["workshop-synth-endpoint-alerts"]')" "$MATCH_ALL" "alerts")"
PUT_S="$(rule_put_body "A2A Lab — workshop data (endpoint alerts)" "$(jq -n '["workshop-synth-endpoint-alerts"]')" "$MATCH_ALL")"
upsert_rule "$sec_kb" "$sec_user" "$sec_pass" "a2a-lab-rule-security-endpoint-hits" "$POST_S" "$PUT_S" "$wf_sec"

echo "== Lab alert rules: Observability Kibana =="
rule_recreate_if_consumer_mismatch "$o11y_kb" "$o11y_user" "$o11y_pass" "a2a-lab-rule-o11y-metrics-hits" "observability"
POST_M="$(rule_json "A2A Lab — workshop data (metrics)" "$(jq -n '["workshop-synth-metrics"]')" "$MATCH_ALL" "observability")"
PUT_M="$(rule_put_body "A2A Lab — workshop data (metrics)" "$(jq -n '["workshop-synth-metrics"]')" "$MATCH_ALL")"
upsert_rule "$o11y_kb" "$o11y_user" "$o11y_pass" "a2a-lab-rule-o11y-metrics-hits" "$POST_M" "$PUT_M" "$wf_o11y"

rule_recreate_if_consumer_mismatch "$o11y_kb" "$o11y_user" "$o11y_pass" "a2a-lab-rule-o11y-traces-hits" "observability"
POST_T="$(rule_json "A2A Lab — workshop data (traces)" "$(jq -n '["workshop-synth-traces"]')" "$MATCH_ALL" "observability")"
PUT_T="$(rule_put_body "A2A Lab — workshop data (traces)" "$(jq -n '["workshop-synth-traces"]')" "$MATCH_ALL")"
upsert_rule "$o11y_kb" "$o11y_user" "$o11y_pass" "a2a-lab-rule-o11y-traces-hits" "$POST_T" "$PUT_T" "$wf_o11y"

echo ""
echo "Rules run every **${LAB_RULE_INTERVAL}** while enabled (override with **A2A_LAB_RULE_INTERVAL**, e.g. \`15m\`)."
echo "  • **Observability** Kibana: open **Observability → Alerts** (lab rules use consumer **observability**). Also: **Stack Management → Rules** (tag **a2a-lab**)."
echo "  • **Security** Kibana: lab rules use consumer **alerts** — check **Stack Management → Rules** and your deployment’s **Alerts** views; **Elastic Security → Alerts** stays detection-centric."
echo "ES|QL in Dev Tools does **not** create these — only alerting rules do."
echo "When **state/kibana-workflows-lab.json** exists (from **06**), **07** attaches **A2A Lab — O11y alert log** / **alert audit (console)** to each lab rule automatically (system connector **system-connector-.workflows**). Otherwise add **Actions → Workflow** in the UI. Set **A2A_SKIP_ATTACH_WORKFLOW_RULE_ACTIONS=1** to skip API attachment."
