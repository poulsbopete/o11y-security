#!/usr/bin/env bash
# Create or update lab Kibana Workflows (YAML) on both Serverless Kibanas via
# POST /api/workflows/workflow and PUT /api/workflows/workflow/{id}.
#
# Requires: curl, jq, bash. Uses bootstrap admin credentials (same as 05).
#
# Writes: state/kibana-workflows-lab.json (workflow ids for idempotent updates).
#
# After this runs, attach workflows from Stack Management → Rules → Actions
# (workflow action) or per-product alerting UI.
#
# Skip: A2A_SKIP_KIBANA_WORKFLOWS=1 in .env
# Skip only the scheduled ingest injectors: A2A_SKIP_SCHEDULED_SYNTH_WORKFLOWS=1
# Skip the on-demand manual synth inject workflows: A2A_SKIP_MANUAL_SYNTH_WORKFLOWS=1
#
# Optional overrides (after bootstrap.json is read):
#   A2A_O11Y_KIBANA_URL / A2A_O11Y_KIBANA_USER / A2A_O11Y_KIBANA_PASSWORD
#   A2A_SEC_KIBANA_URL  / A2A_SEC_KIBANA_USER  / A2A_SEC_KIBANA_PASSWORD
# URLs may be the Kibana origin only, or a deep link (…/app/workflows is stripped).
# Observability workflows only (no Security Kibana required): A2A_WORKFLOWS_OBSERVABILITY_ONLY=1
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

CURL="${CURL:-/usr/bin/curl}"
BOOT="$ROOT/state/bootstrap.json"
STATE="$ROOT/state/kibana-workflows-lab.json"
YAML_DIR="$ROOT/kibana-workflows/yaml"

load_dotenv "$ROOT/.env"

if [ "${A2A_SKIP_KIBANA_WORKFLOWS:-0}" = "1" ]; then
  echo "Skipping Kibana Workflows (A2A_SKIP_KIBANA_WORKFLOWS=1)."
  exit 0
fi

if [ ! -f "$BOOT" ]; then
  echo "Missing ${BOOT} — run 01-provision-serverless.sh first." >&2
  exit 1
fi

require_cmds "$CURL" jq

umask 077
mkdir -p "$ROOT/state"

# Kibana API base: strip "/app/…" if someone pastes a Workflows UI URL.
wf_normalize_kibana_base() {
  local u="${1%/}"
  case "$u" in
    */app|*/app/*) printf '%s' "${u%%/app*}" ;;
    *) printf '%s' "$u" ;;
  esac
}

if [ ! -f "$STATE" ]; then
  echo '{"security":{},"observability":{}}' >"$STATE"
  chmod 600 "$STATE"
fi

wf_put() {
  local base="$1" user="$2" pass="$3" id="$4" yaml_file="$5"
  local tmp code
  tmp="$(mktemp)"
  jq -n --rawfile y "$yaml_file" '{yaml:$y}' >"$tmp"
  code="$("$CURL" -sS -o /tmp/wf-resp.json -w "%{http_code}" -u "${user}:${pass}" \
    -H "kbn-xsrf: true" -H "Content-Type: application/json" \
    -X PUT "${base%/}/api/workflows/workflow/${id}" -d @"$tmp")" || true
  rm -f "$tmp"
  printf '%s' "$code"
}

wf_post() {
  local base="$1" user="$2" pass="$3" id="$4" yaml_file="$5"
  local tmp code
  tmp="$(mktemp)"
  jq -n --rawfile y "$yaml_file" --arg id "$id" '{id:$id, yaml:$y}' >"$tmp"
  code="$("$CURL" -sS -o /tmp/wf-resp.json -w "%{http_code}" -u "${user}:${pass}" \
    -H "kbn-xsrf: true" -H "Content-Type: application/json" \
    -X POST "${base%/}/api/workflows/workflow" -d @"$tmp")" || true
  rm -f "$tmp"
  printf '%s' "$code"
}

wf_find_by_name() {
  local base="$1" user="$2" pass="$3" want_name="$4"
  local tmp out
  tmp="$(mktemp)"
  if ! "$CURL" -sS -o "$tmp" -u "${user}:${pass}" -H "kbn-xsrf: true" "${base%/}/api/workflows?size=100"; then
    rm -f "$tmp"
    return 1
  fi
  out="$(jq -r --arg n "$want_name" '[.results[]? | select(.name == $n) | .id][0] // empty' "$tmp")"
  rm -f "$tmp"
  printf '%s' "$out"
}

wf_upsert() {
  local role="$1" key="$2" yaml_file="$3" base="$4" user="$5" pass="$6"
  local id new_id code name valid want_name

  if [ ! -f "$yaml_file" ]; then
    echo "Missing YAML: $yaml_file" >&2
    return 1
  fi

  want_name="$(awk -F': ' '/^name:/{print $2; exit}' "$yaml_file")"
  if [ -z "$want_name" ]; then
    echo "Could not read workflow name from ${yaml_file}" >&2
    return 1
  fi

  id="$(jq -r --arg r "$role" --arg k "$key" '.[$r][$k] // empty' "$STATE")"
  if [ -z "$id" ] || [ "$id" = "null" ]; then
    id="$(wf_find_by_name "$base" "$user" "$pass" "$want_name")"
    if [ -n "$id" ]; then
      local merged
      merged="$(jq --arg r "$role" --arg k "$key" --arg id "$id" '.[$r][$k]=$id' "$STATE")"
      printf '%s\n' "$merged" >"$STATE"
      chmod 600 "$STATE"
      echo "  Found existing ${role}/${key} id=${id} (name match)"
    fi
  fi
  if [ -n "$id" ] && [ "$id" != "null" ]; then
    code="$(wf_put "$base" "$user" "$pass" "$id" "$yaml_file")"
    if [ "$code" = "200" ]; then
      valid="$(jq -r '.valid // empty' /tmp/wf-resp.json 2>/dev/null || true)"
      echo "  PUT ${role}/${key} id=${id} (valid=${valid})"
      return 0
    fi
    echo "  WARN: PUT ${id} returned HTTP ${code}; recreating…" >&2
    head -c 800 /tmp/wf-resp.json >&2 || true
    echo >&2
  fi

  new_id="workflow-$(uuidgen | tr '[:upper:]' '[:lower:]')"
  code="$(wf_post "$base" "$user" "$pass" "$new_id" "$yaml_file")"
  if [ "$code" != "200" ]; then
    echo "POST workflow failed HTTP ${code}" >&2
    cat /tmp/wf-resp.json >&2 || true
    return 1
  fi
  valid="$(jq -r '.valid // false' /tmp/wf-resp.json)"
  name="$(jq -r '.name // empty' /tmp/wf-resp.json)"
  if [ "$valid" != "true" ]; then
    echo "Workflow saved but invalid=true not set (valid=$valid): $name" >&2
    jq . /tmp/wf-resp.json >&2 || true
    return 1
  fi
  local merged
  merged="$(jq --arg r "$role" --arg k "$key" --arg id "$new_id" '.[$r][$k]=$id' "$STATE")"
  printf '%s\n' "$merged" >"$STATE"
  chmod 600 "$STATE"
  echo "  POST ${role}/${key} id=${new_id} (${name})"
}

sec_kb="$(jq -r '.security.endpoints.kibana // empty' "$BOOT")"
sec_user="$(jq -r '.security.credentials.username // empty' "$BOOT")"
sec_pass="$(jq -r '.security.credentials.password // empty' "$BOOT")"
o11y_kb="$(jq -r '.observability.endpoints.kibana // empty' "$BOOT")"
o11y_user="$(jq -r '.observability.credentials.username // empty' "$BOOT")"
o11y_pass="$(jq -r '.observability.credentials.password // empty' "$BOOT")"

if [ -n "${A2A_SEC_KIBANA_URL:-}" ]; then sec_kb="$A2A_SEC_KIBANA_URL"; fi
if [ -n "${A2A_SEC_KIBANA_USER:-}" ]; then sec_user="$A2A_SEC_KIBANA_USER"; fi
if [ -n "${A2A_SEC_KIBANA_PASSWORD:-}" ]; then sec_pass="$A2A_SEC_KIBANA_PASSWORD"; fi
if [ -n "${A2A_O11Y_KIBANA_URL:-}" ]; then o11y_kb="$A2A_O11Y_KIBANA_URL"; fi
if [ -n "${A2A_O11Y_KIBANA_USER:-}" ]; then o11y_user="$A2A_O11Y_KIBANA_USER"; fi
if [ -n "${A2A_O11Y_KIBANA_PASSWORD:-}" ]; then o11y_pass="$A2A_O11Y_KIBANA_PASSWORD"; fi

sec_kb="$(wf_normalize_kibana_base "$sec_kb")"
o11y_kb="$(wf_normalize_kibana_base "$o11y_kb")"

if [ "${A2A_WORKFLOWS_OBSERVABILITY_ONLY:-0}" != "1" ]; then
  if [ -z "$sec_kb" ] || [ -z "$sec_user" ] || [ -z "$sec_pass" ]; then
    echo "Missing Security Kibana URL or credentials (bootstrap.json or A2A_SEC_KIBANA_*)." >&2
    exit 1
  fi
fi
if [ -z "$o11y_kb" ] || [ -z "$o11y_user" ] || [ -z "$o11y_pass" ]; then
  echo "Missing Observability Kibana URL or credentials (bootstrap.json or A2A_O11Y_KIBANA_*)." >&2
  exit 1
fi

if [ "${A2A_WORKFLOWS_OBSERVABILITY_ONLY:-0}" != "1" ]; then
  echo "== Kibana Workflows: Security project =="
  wf_upsert security alert_console "$YAML_DIR/security-alert-console.yaml" "$sec_kb" "$sec_user" "$sec_pass"
  wf_upsert security alert_to_case "$YAML_DIR/security-alert-to-case.yaml" "$sec_kb" "$sec_user" "$sec_pass"
  if [ "${A2A_SKIP_SCHEDULED_SYNTH_WORKFLOWS:-0}" != "1" ]; then
    wf_upsert security scheduled_inject "$YAML_DIR/security-scheduled-synth-inject.yaml" "$sec_kb" "$sec_user" "$sec_pass"
  else
    echo "Skipping scheduled Security synth inject (A2A_SKIP_SCHEDULED_SYNTH_WORKFLOWS=1)."
  fi
  if [ "${A2A_SKIP_MANUAL_SYNTH_WORKFLOWS:-0}" != "1" ]; then
    wf_upsert security synth_inject_manual "$YAML_DIR/security-synth-inject-manual.yaml" "$sec_kb" "$sec_user" "$sec_pass"
  else
    echo "Skipping manual Security synth inject (A2A_SKIP_MANUAL_SYNTH_WORKFLOWS=1)."
  fi
else
  echo "== Kibana Workflows: Security project (skipped, A2A_WORKFLOWS_OBSERVABILITY_ONLY=1) =="
fi

echo "== Kibana Workflows: Observability project =="
wf_upsert observability alert_console "$YAML_DIR/observability-alert-console.yaml" "$o11y_kb" "$o11y_user" "$o11y_pass"
wf_upsert observability alert_to_case "$YAML_DIR/observability-alert-to-case.yaml" "$o11y_kb" "$o11y_user" "$o11y_pass"
if [ "${A2A_SKIP_SCHEDULED_SYNTH_WORKFLOWS:-0}" != "1" ]; then
  wf_upsert observability scheduled_inject "$YAML_DIR/observability-scheduled-synth-inject.yaml" "$o11y_kb" "$o11y_user" "$o11y_pass"
else
  echo "Skipping scheduled Observability synth inject (A2A_SKIP_SCHEDULED_SYNTH_WORKFLOWS=1)."
fi
if [ "${A2A_SKIP_MANUAL_SYNTH_WORKFLOWS:-0}" != "1" ]; then
  wf_upsert observability synth_inject_manual "$YAML_DIR/observability-synth-inject-manual.yaml" "$o11y_kb" "$o11y_user" "$o11y_pass"
else
  echo "Skipping manual Observability synth inject (A2A_SKIP_MANUAL_SYNTH_WORKFLOWS=1)."
fi

echo "Wrote ${STATE}"
echo "Next: run **scripts/07-lab-alert-rules.sh** so lab rules get the **alert console** workflow action automatically (when this script wrote **state/kibana-workflows-lab.json**)."
echo "  • Or in each Kibana: **Stack Management → Rules** → rule → **Actions** → **Workflow** → **A2A Lab — O11y alert log** / **alert audit (console)** (same outcome)."
echo "  • The separate **… alert to Case** workflows are optional (case-only); do **not** attach them on the same rule as the log/audit workflow."
echo "  • **Scheduled inject** (default **15m**) pushes workshop docs automatically; **manual inject** workflows run only when you click **Run** in **Workflows**."
echo "  • To stop all background injectors: **A2A_SKIP_SCHEDULED_SYNTH_WORKFLOWS=1** (keep manual), or disable the scheduled workflow in Kibana."
