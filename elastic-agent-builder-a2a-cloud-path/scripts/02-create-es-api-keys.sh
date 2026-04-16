#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_cmds curl jq

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOT="$ROOT/state/bootstrap.json"
if [ ! -f "$BOOT" ]; then
  echo "Missing ${BOOT} — run 01-provision-serverless.sh first." >&2
  exit 1
fi

mkkey() {
  local es_url="$1" user="$2" pass="$3"
  local resp enc
  resp="$(curl -sS -u "${user}:${pass}" -X POST "${es_url}/_security/api_key" \
    -H 'Content-Type: application/json' \
    --data-binary @"$SCRIPT_DIR/api-key-body.json")"
  enc="$(echo "$resp" | jq -r '.encoded // empty')"
  if [ -z "$enc" ]; then
    echo "Elasticsearch API key creation failed:" >&2
    echo "$resp" | jq . >&2 2>/dev/null || echo "$resp" >&2
    exit 1
  fi
  printf '%s' "$enc"
}

o11y_es="$(jq -r '.observability.endpoints.elasticsearch // empty' "$BOOT")"
o11y_kb="$(jq -r '.observability.endpoints.kibana // empty' "$BOOT")"
o11y_user="$(jq -r '.observability.credentials.username // empty' "$BOOT")"
o11y_pass="$(jq -r '.observability.credentials.password // empty' "$BOOT")"
sec_es="$(jq -r '.security.endpoints.elasticsearch // empty' "$BOOT")"
sec_kb="$(jq -r '.security.endpoints.kibana // empty' "$BOOT")"
sec_user="$(jq -r '.security.credentials.username // empty' "$BOOT")"
sec_pass="$(jq -r '.security.credentials.password // empty' "$BOOT")"

for v in o11y_es o11y_kb o11y_user o11y_pass sec_es sec_kb sec_user sec_pass; do
  if [ -z "${!v}" ]; then
    echo "Missing field in bootstrap.json (${v})." >&2
    exit 1
  fi
done

o11y_agent_url="${o11y_kb%/}/api/agent_builder/converse"
sec_agent_url="${sec_kb%/}/api/agent_builder/converse"

echo "Creating Elasticsearch API keys (scoped via api-key-body.json)…"
o11y_key="$(mkkey "$o11y_es" "$o11y_user" "$o11y_pass")"
sec_key="$(mkkey "$sec_es" "$sec_user" "$sec_pass")"

umask 077
cat >"$ROOT/state/workshop.env" <<EOF
O11Y_ES_URL=${o11y_es}
O11Y_API_KEY=${o11y_key}
SECURITY_ES_URL=${sec_es}
SECURITY_API_KEY=${sec_key}
# Cross-project Agent Builder HTTP (same Kibana …/converse URLs scripts/06 uses to render alert workflows)
O11Y_AGENT_ENDPOINT=${o11y_agent_url}
SECURITY_AGENT_ENDPOINT=${sec_agent_url}
EOF
chmod 600 "$ROOT/state/workshop.env"

echo "Wrote ${ROOT}/state/workshop.env (chmod 600)."
echo "  (includes O11Y_AGENT_ENDPOINT + SECURITY_AGENT_ENDPOINT from bootstrap Kibana URLs)"
echo "Use it with ELASTIC_WORKSHOP_ENV_FILE when running workshop scripts, or copy values into your Instruqt .env."
