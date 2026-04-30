#!/usr/bin/env bash
# Run **saved** lab Kibana Workflows once via POST /api/workflows/test with a **synthetic**
# alert payload — no waiting for the alerting scheduler. Useful right after **06**.
#
# This does **not** replace **ingest + alerting rules**: it does not bulk new docs or force a rule
# schedule. To push traffic so **07** lab rules match fresh data, run **10-lab-simulate-traffic.sh**.
#
# Synthetic payloads use the **real lab rule name substrings** (traces / endpoint) so case titles
# exercise the dual-mission Liquid in the alert workflows. Alert UUID last digit selects the drill variant.
# The **console** lab workflows (**A2A Lab — O11y alert log** / **alert audit (console)**) each run
# **console + createCase**; this script therefore creates **real** Security / Observability cases
# unless you skip it.
#
# Optional: set A2A_TEST_WORKFLOWS_INCLUDE_CASES=1 to **also** run the standalone **… alert to Case**
# workflows (creates a second synthetic case per project — for testing that YAML path only).
#
# Requires: curl, jq, bash, state/bootstrap.json, state/kibana-workflows-lab.json.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

CURL="${CURL:-/usr/bin/curl}"
BOOT="$ROOT/state/bootstrap.json"
WF_STATE="$ROOT/state/kibana-workflows-lab.json"

load_dotenv "$ROOT/.env"

if [ ! -f "$BOOT" ] || [ ! -f "$WF_STATE" ]; then
  echo "Need ${BOOT} and ${WF_STATE} (run scripts/06-kibana-workflows-lab.sh first)." >&2
  exit 1
fi

require_cmds "$CURL" jq

SYNTH_INPUTS="$(jq -n '{
  event: {
    alerts: [
      {
        kibana: {
          alert: {
            rule: {name: "A2A Lab — workshop data (traces)", uuid: "00000000-0000-0000-0000-00000000000a"},
            reason: "Synthetic inputs from scripts/08-synthetic-workflow-test.sh (dual-mission title check: traces → Web / API)",
            uuid: "00000000-0000-0000-0000-000000000002",
            status: "active"
          }
        },
        host: {name: "prod-db-01"}
      }
    ]
  }
}')"

SYNTH_INPUTS_SEC="$(jq -n '{
  event: {
    alerts: [
      {
        kibana: {
          alert: {
            rule: {name: "A2A Lab — workshop data (endpoint alerts)", uuid: "00000000-0000-0000-0000-000000000001"},
            reason: "Synthetic inputs from scripts/08-synthetic-workflow-test.sh (dual-mission title check: endpoint → Database)",
            uuid: "00000000-0000-0000-0000-000000000003",
            status: "active"
          }
        },
        host: {name: "prod-db-01"}
      }
    ]
  }
}')"

wf_test() {
  local base="$1" user="$2" pass="$3" wf_id="$4" label="$5"
  local inputs_json="${6:-$SYNTH_INPUTS}"
  local tmp code
  tmp="$(mktemp)"
  jq -n --arg wid "$wf_id" --argjson inputs "$inputs_json" '{workflowId:$wid, inputs:$inputs}' >"$tmp"
  code="$("$CURL" -sS -o /tmp/wt.json -w "%{http_code}" -u "${user}:${pass}" \
    -H "kbn-xsrf: true" -H "Content-Type: application/json" \
    -X POST "${base%/}/api/workflows/test" -d @"$tmp")" || true
  rm -f "$tmp"
  if [ "$code" = "200" ]; then
    echo "  OK ${label} id=${wf_id} → $(jq -c . /tmp/wt.json)"
    return 0
  fi
  echo "  FAIL ${label} HTTP ${code}" >&2
  cat /tmp/wt.json >&2 || true
  return 1
}

sec_kb="$(jq -r '.security.endpoints.kibana // empty' "$BOOT")"
sec_user="$(jq -r '.security.credentials.username // empty' "$BOOT")"
sec_pass="$(jq -r '.security.credentials.password // empty' "$BOOT")"
o11y_kb="$(jq -r '.observability.endpoints.kibana // empty' "$BOOT")"
o11y_user="$(jq -r '.observability.credentials.username // empty' "$BOOT")"
o11y_pass="$(jq -r '.observability.credentials.password // empty' "$BOOT")"

echo "== Synthetic workflow test: Security (console + case in one workflow) =="
wf_test "$sec_kb" "$sec_user" "$sec_pass" "$(jq -r '.security.alert_console' "$WF_STATE")" "Security alert audit (console)" "$SYNTH_INPUTS_SEC"

if [ "${A2A_TEST_WORKFLOWS_INCLUDE_CASES:-0}" = "1" ]; then
  wf_test "$sec_kb" "$sec_user" "$sec_pass" "$(jq -r '.security.alert_to_case' "$WF_STATE")" "Security case-only (extra)"
else
  echo "  (skip Security case-only workflow; set A2A_TEST_WORKFLOWS_INCLUDE_CASES=1 for a second synthetic case)"
fi

echo "== Synthetic workflow test: Observability (console + case in one workflow) =="
wf_test "$o11y_kb" "$o11y_user" "$o11y_pass" "$(jq -r '.observability.alert_console' "$WF_STATE")" "Observability alert log"

if [ "${A2A_TEST_WORKFLOWS_INCLUDE_CASES:-0}" = "1" ]; then
  wf_test "$o11y_kb" "$o11y_user" "$o11y_pass" "$(jq -r '.observability.alert_to_case' "$WF_STATE")" "Observability case-only (extra)"
else
  echo "  (skip Observability case-only workflow; set A2A_TEST_WORKFLOWS_INCLUDE_CASES=1 for a second synthetic case)"
fi

echo "Check **Stack Management → Workflows → Executions** and **Cases** for results."
