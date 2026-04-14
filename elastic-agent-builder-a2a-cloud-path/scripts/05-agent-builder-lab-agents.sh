#!/usr/bin/env bash
# After Serverless projects are up and workshop data exists, create lab Agent Builder
# agents via the official kibana-agent-builder CLI (Elastic Agent Skills).
#
# Requires: Node.js 18+ with fetch(), jq, curl.
# Optional: AGENT_BUILDER_JS path to agent-builder.js; else common install paths are tried.
# Skip entirely: A2A_SKIP_AGENT_BUILDER=1 in .env
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
load_dotenv "$ROOT/.env"

if [ "${A2A_SKIP_AGENT_BUILDER:-0}" = "1" ]; then
  echo "Skipping Agent Builder automation (A2A_SKIP_AGENT_BUILDER=1)."
  exit 0
fi

BOOT="$ROOT/state/bootstrap.json"
if [ ! -f "$BOOT" ]; then
  echo "Missing ${BOOT} — run 01-provision-serverless.sh first." >&2
  exit 1
fi

WS_ENV="$ROOT/state/workshop.env"
if [ ! -f "$WS_ENV" ]; then
  echo "Missing ${WS_ENV} — run 02-create-es-api-keys.sh and 03-populate-indices.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$WS_ENV"
set +a

require_cmds curl jq

if ! command -v node >/dev/null 2>&1; then
  echo "WARN: node not found — skipping Agent Builder automation. Install Node 18+ or set A2A_SKIP_AGENT_BUILDER=1." >&2
  exit 0
fi

resolve_agent_builder_js() {
  if [ -n "${AGENT_BUILDER_JS:-}" ] && [ -f "${AGENT_BUILDER_JS}" ]; then
    printf '%s' "${AGENT_BUILDER_JS}"
    return 0
  fi
  if [ -n "${ELASTIC_AGENT_SKILLS_ROOT:-}" ]; then
    local p="${ELASTIC_AGENT_SKILLS_ROOT}/skills/kibana/agent-builder/scripts/agent-builder.js"
    if [ -f "$p" ]; then
      printf '%s' "$p"
      return 0
    fi
  fi
  local c
  for c in \
    "${HOME}/.agents/skills/kibana-agent-builder/scripts/agent-builder.js" \
    "${HOME}/.cursor/skills/kibana-agent-builder/scripts/agent-builder.js" \
    "${HOME}/.claude/skills/kibana-agent-builder/scripts/agent-builder.js"; do
    if [ -f "$c" ]; then
      printf '%s' "$c"
      return 0
    fi
  done
  return 1
}

AB_CLI="$(resolve_agent_builder_js)" || AB_CLI=""

if [ -z "$AB_CLI" ]; then
  echo "WARN: kibana-agent-builder CLI not found (agent-builder.js)." >&2
  echo "      Install from https://github.com/elastic/agent-skills (kibana-agent-builder) or set AGENT_BUILDER_JS." >&2
  echo "      Skipping Agent Builder automation."
  exit 0
fi

wait_kibana() {
  local base user pass n
  base="${1%/}"
  user="$2"
  pass="$3"
  n=0
  while [ "$n" -lt 36 ]; do
    if curl -sf -u "${user}:${pass}" -H "kbn-xsrf: true" "${base}/api/status" >/dev/null; then
      return 0
    fi
    echo "Waiting for Kibana ${base}… ($((n + 1))/36)"
    sleep 10
    n=$((n + 1))
  done
  echo "Kibana did not become ready: ${base}" >&2
  return 1
}

platform_tool_csv() {
  local base user pass json
  base="${1%/}"
  user="$2"
  pass="$3"
  if ! json="$(curl -sSf -u "${user}:${pass}" -H "kbn-xsrf: true" "${base}/api/agent_builder/tools")"; then
    json="{}"
  fi
  echo "$json" | jq -r '
    (if (.results | type) == "array" then .results elif (. | type) == "array" then . else [] end)
    | map(select((.id // "") | startswith("platform.core.")))
    | map(.id)
    | join(",")
  ' 2>/dev/null || true
}

run_ab() {
  # Run from cloud-path root so Node's optional .env loader does not pick up the skill directory.
  (cd "$ROOT" && node "$AB_CLI" "$@")
}

tool_exists() {
  local tid="$1"
  if run_ab get-tool --id "$tid" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

agent_exists() {
  local aid="$1"
  if run_ab get-agent --id "$aid" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

upsert_index_search_tool() {
  local tid pattern desc
  tid="$1"
  pattern="$2"
  desc="$3"
  if tool_exists "$tid"; then
    echo "  Tool ${tid} already exists."
    return 0
  fi
  echo "  Creating tool ${tid} (index_search ${pattern})…"
  run_ab create-tool --id "$tid" --type index_search --description "$desc" --pattern "$pattern"
}

upsert_agent() {
  local aid name desc tools_file instr_file
  aid="$1"
  name="$2"
  desc="$3"
  tools_file="$4"
  instr_file="$5"
  if agent_exists "$aid"; then
    echo "  Agent ${aid} already exists."
    return 0
  fi
  local tools_csv instr
  tools_csv="$(tr -d '\n' <"$tools_file")"
  instr="$(cat "$instr_file")"
  echo "  Creating agent ${aid}…"
  run_ab create-agent --name "$name" --description "$desc" --tool-ids "$tools_csv" --instructions "$instr"
}

# Substitute __O11Y_ENDPOINT__ in enrichment template (URL may contain sed-special chars).
render_enrichment_instructions() {
  local out="$1"
  local ep="${O11Y_AGENT_ENDPOINT:-not configured — set O11Y_AGENT_ENDPOINT in state/workshop.env}"
  if command -v python3 >/dev/null 2>&1; then
    ROOT="$ROOT" EP="$ep" python3 -c "import os, pathlib; r=os.environ['ROOT']; ep=os.environ['EP']; p=pathlib.Path(r)/'agent-instructions/security-a2a-enrichment.txt'; print(p.read_text().replace('__O11Y_ENDPOINT__', ep))" >"$out"
  else
    local esc
    esc="$(printf '%s' "$ep" | sed 's/[\\/&|]/\\&/g')"
    sed "s/__O11Y_ENDPOINT__/${esc}/g" "$ROOT/agent-instructions/security-a2a-enrichment.txt" >"$out"
  fi
  chmod 600 "$out"
}

# --- Security Kibana ---
sec_kb="$(jq -r '.security.endpoints.kibana // empty' "$BOOT")"
sec_user="$(jq -r '.security.credentials.username // empty' "$BOOT")"
sec_pass="$(jq -r '.security.credentials.password // empty' "$BOOT")"
if [ -z "$sec_kb" ] || [ -z "$sec_user" ] || [ -z "$sec_pass" ]; then
  echo "Missing Security Kibana URL or credentials in bootstrap.json." >&2
  exit 1
fi

echo "== Agent Builder: Security project =="
export KIBANA_URL="${sec_kb}"
export KIBANA_USERNAME="${sec_user}"
export KIBANA_PASSWORD="${sec_pass}"
unset KIBANA_API_KEY 2>/dev/null || true

wait_kibana "$sec_kb" "$sec_user" "$sec_pass"

sec_platform="$(platform_tool_csv "$sec_kb" "$sec_user" "$sec_pass")"
if [ -z "$sec_platform" ]; then
  echo "WARN: no platform.core.* tools listed; using fallback platform.core.search only." >&2
  sec_platform="platform.core.search"
fi

TOOL_SEC_SEARCH="a2a-workshop-endpoint-alerts"
upsert_index_search_tool "$TOOL_SEC_SEARCH" "workshop-synth-endpoint-alerts" \
  "Search synthetic endpoint authentication failure events for the A2A lab."

{
  echo -n "${TOOL_SEC_SEARCH},${sec_platform}"
} >"$ROOT/state/.ab-tools-security.tmp"
chmod 600 "$ROOT/state/.ab-tools-security.tmp"

upsert_agent "a2a-lab-security-detection" "A2A Lab Security Detection" \
  "Workshop detection agent over workshop-synth-endpoint-alerts" \
  "$ROOT/state/.ab-tools-security.tmp" \
  "$ROOT/agent-instructions/security-detection.txt"

render_enrichment_instructions "$ROOT/state/.ab-enrich-instr.tmp"
upsert_agent "a2a-lab-security-a2a-enrichment" "A2A Lab Security A2A Enrichment" \
  "Workshop Security agent: correlate endpoint alerts with Observability context (A2A)" \
  "$ROOT/state/.ab-tools-security.tmp" \
  "$ROOT/state/.ab-enrich-instr.tmp"

rm -f "$ROOT/state/.ab-tools-security.tmp" "$ROOT/state/.ab-enrich-instr.tmp"

# --- Observability Kibana ---
o11y_kb="$(jq -r '.observability.endpoints.kibana // empty' "$BOOT")"
o11y_user="$(jq -r '.observability.credentials.username // empty' "$BOOT")"
o11y_pass="$(jq -r '.observability.credentials.password // empty' "$BOOT")"
if [ -z "$o11y_kb" ] || [ -z "$o11y_user" ] || [ -z "$o11y_pass" ]; then
  echo "Missing Observability Kibana URL or credentials in bootstrap.json." >&2
  exit 1
fi

echo "== Agent Builder: Observability project =="
export KIBANA_URL="${o11y_kb}"
export KIBANA_USERNAME="${o11y_user}"
export KIBANA_PASSWORD="${o11y_pass}"
unset KIBANA_API_KEY 2>/dev/null || true

wait_kibana "$o11y_kb" "$o11y_user" "$o11y_pass"

o11y_platform="$(platform_tool_csv "$o11y_kb" "$o11y_user" "$o11y_pass")"
if [ -z "$o11y_platform" ]; then
  echo "WARN: no platform.core.* tools on Observability; using platform.core.search." >&2
  o11y_platform="platform.core.search"
fi

TOOL_MET="a2a-workshop-metrics"
TOOL_TR="a2a-workshop-traces"
upsert_index_search_tool "$TOOL_MET" "workshop-synth-metrics" "Lab synthetic host metrics for A2A context."
upsert_index_search_tool "$TOOL_TR" "workshop-synth-traces" "Lab synthetic traces for A2A context."

{
  echo -n "${TOOL_MET},${TOOL_TR},${o11y_platform}"
} >"$ROOT/state/.ab-tools-o11y.tmp"
chmod 600 "$ROOT/state/.ab-tools-o11y.tmp"

upsert_agent "a2a-lab-observability-context" "A2A Lab Observability Context" \
  "Workshop context agent over workshop-synth-metrics and workshop-synth-traces" \
  "$ROOT/state/.ab-tools-o11y.tmp" \
  "$ROOT/agent-instructions/observability-context.txt"

rm -f "$ROOT/state/.ab-tools-o11y.tmp"

# If Observability URL was added after the first run, patch enrichment instructions on Security Kibana.
echo "== Optional: sync Security enrichment agent with O11Y_AGENT_ENDPOINT =="
export KIBANA_URL="${sec_kb}"
export KIBANA_USERNAME="${sec_user}"
export KIBANA_PASSWORD="${sec_pass}"
unset KIBANA_API_KEY 2>/dev/null || true
if [ -n "${O11Y_AGENT_ENDPOINT:-}" ] && agent_exists "a2a-lab-security-a2a-enrichment"; then
  render_enrichment_instructions "$ROOT/state/.ab-enrich-instr.tmp"
  instr="$(cat "$ROOT/state/.ab-enrich-instr.tmp")"
  echo "  Updating a2a-lab-security-a2a-enrichment instructions…"
  run_ab update-agent --id "a2a-lab-security-a2a-enrichment" --instructions "$instr"
  rm -f "$ROOT/state/.ab-enrich-instr.tmp"
fi

umask 077
ep_set="false"
if [ -n "${O11Y_AGENT_ENDPOINT:-}" ]; then
  ep_set="true"
fi
jq -n \
  --arg sec_agent "a2a-lab-security-detection" \
  --arg sec_enrich "a2a-lab-security-a2a-enrichment" \
  --arg o11y_agent "a2a-lab-observability-context" \
  --arg sec_tool "$TOOL_SEC_SEARCH" \
  --arg o11y_tools "${TOOL_MET},${TOOL_TR}" \
  --arg o11y_endpoint_set "$ep_set" \
  --arg o11y_endpoint "${O11Y_AGENT_ENDPOINT:-}" \
  '{
    security_detection_agent_id:$sec_agent,
    security_a2a_enrichment_agent_id:$sec_enrich,
    observability_context_agent_id:$o11y_agent,
    security_tool_id:$sec_tool,
    observability_tool_ids:$o11y_tools,
    o11y_agent_endpoint_configured: ($o11y_endpoint_set == "true"),
    o11y_agent_endpoint: (if $o11y_endpoint == "" then null else $o11y_endpoint end)
  }' >"$ROOT/state/agent-builder-lab.json"
chmod 600 "$ROOT/state/agent-builder-lab.json"

echo "Wrote ${ROOT}/state/agent-builder-lab.json"
echo "Agent Builder lab agents: Security (detection + A2A enrichment) + Observability (context)."
if [ -z "${O11Y_AGENT_ENDPOINT:-}" ]; then
  echo "Note: O11Y_AGENT_ENDPOINT is not set in workshop.env — enrichment agent instructions use a placeholder; set the URL and re-run this script to refresh wording (or edit the agent in Kibana)."
fi
