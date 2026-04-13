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

cat <<EOF

--- Agent Builder (manual in each Kibana) ---
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
