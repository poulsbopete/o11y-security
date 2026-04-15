#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOT="$ROOT/state/bootstrap.json"
WS="$(workshop_root)"

if [ ! -f "$BOOT" ]; then
  echo "No ${BOOT} yet — run provisioning first." >&2
  exit 1
fi

o11y_kb="$(jq -r '.observability.endpoints.kibana // empty' "$BOOT")"
sec_kb="$(jq -r '.security.endpoints.kibana // empty' "$BOOT")"
ab_lab="${ROOT}/state/agent-builder-lab.json"
wf_lab="${ROOT}/state/kibana-workflows-lab.json"
dash_lab="${ROOT}/state/kibana-dashboards-lab.json"

cat <<EOF

--- Agent Builder (Kibana URLs; run scripts/05-agent-builder-lab-agents.sh to create lab agents) ---
Observability Kibana: ${o11y_kb}
Security Kibana:      ${sec_kb}

Scaffolds + payload shapes live here:
  ${WS}/agent-scaffolds/

Suggested order:
  1) Security project: detection agent -> index .elastic-agents-security-detections
  2) Observability project: context agent -> expose HTTPS endpoint; document in artifacts/o11y-agent-contract.md (Instruqt) or your runbook
  3) Security project: A2A enrichment -> .elastic-agents-security-a2a-enriched

After you publish the Observability agent URL, append to ${ROOT}/state/workshop.env:
  O11Y_AGENT_ENDPOINT=https://.../your-path

Quick checks (loads keys from workshop.env):
  set -a; source ${ROOT}/state/workshop.env; set +a
  curl -sS -H "Authorization: ApiKey \${SECURITY_API_KEY}" "\${SECURITY_ES_URL}/_cluster/health" | jq .
  curl -sS -H "Authorization: ApiKey \${O11Y_API_KEY}" "\${O11Y_ES_URL}/_cluster/health" | jq .

EOF

if [ -f "$ab_lab" ]; then
  echo "Lab Agent Builder automation (if 05 ran successfully):"
  echo "  ${ab_lab}"
  jq . "$ab_lab" 2>/dev/null || cat "$ab_lab"
  echo ""
fi

if [ -f "$wf_lab" ]; then
  echo "Lab Kibana Workflows (if scripts/06-kibana-workflows-lab.sh ran):"
  echo "  ${wf_lab}"
  jq . "$wf_lab" 2>/dev/null || cat "$wf_lab"
  echo "Attach **A2A Lab — O11y alert log** / **alert audit (console)** to lab rules (Actions → Workflow) — each run logs + opens a case; avoid duplicating the Case-only workflow on the same rule."
  echo "ES|QL / Dev Tools do not create alerting alerts — run scripts/07-lab-alert-rules.sh (or re-run run-all.sh) for lab rules on workshop-* indices."
  echo "Instant workflow smoke test: bash ${ROOT}/scripts/08-synthetic-workflow-test.sh"
  echo ""
fi

if [ -f "$ROOT/state/workshop.env" ]; then
  echo "Simulate traffic for lab rules (optional): bash ${ROOT}/scripts/10-lab-simulate-traffic.sh"
  echo "  (bulk workshop docs on both clusters so **07** rules match; different from **08** synthetic workflow test.)"
  echo ""
fi

if [ -f "$dash_lab" ]; then
  echo "Lab dashboards — Dashboards API (if scripts/09-lab-dashboards-api.sh ran):"
  echo "  ${dash_lab}"
  jq . "$dash_lab" 2>/dev/null || cat "$dash_lab"
  echo "Open Analytics → Dashboards; search **A2A Lab**."
  echo ""
fi
