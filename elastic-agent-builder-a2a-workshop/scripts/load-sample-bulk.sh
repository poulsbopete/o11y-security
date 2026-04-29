#!/usr/bin/env bash
set -euo pipefail

ROOT="${ELASTIC_WORKSHOP_ROOT:-/root/elastic-workshop}"
ENV_FILE="${ELASTIC_WORKSHOP_ENV_FILE:-$ROOT/.env}"
# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

bulk() {
  local url="$1"
  local key="$2"
  local file="$3"
  curl -sS -X POST "${url}/_bulk" \
    -H "Authorization: ApiKey ${key}" \
    -H "Content-Type: application/x-ndjson" \
    --data-binary "@${file}" | jq -e '.errors == false' >/dev/null
}

bulk "$SECURITY_ES_URL" "$SECURITY_API_KEY" "$ROOT/sample-data/endpoint-alerts.ndjson"
bulk "$O11Y_ES_URL" "$O11Y_API_KEY" "$ROOT/sample-data/metrics-host.ndjson"
bulk "$O11Y_ES_URL" "$O11Y_API_KEY" "$ROOT/sample-data/traces-apm.ndjson"
# Mirror metrics + traces onto Security ES so **Security Kibana → ES|QL / Discover** can query
# `workshop-synth-metrics` / `workshop-synth-traces` (those indices only existed on Observability before).
if [ "${WORKSHOP_SKIP_MIRROR_O11Y_INDICES_TO_SECURITY:-0}" != "1" ]; then
  bulk "$SECURITY_ES_URL" "$SECURITY_API_KEY" "$ROOT/sample-data/metrics-host.ndjson"
  bulk "$SECURITY_ES_URL" "$SECURITY_API_KEY" "$ROOT/sample-data/traces-apm.ndjson"
fi

echo "Sample bulk loads completed (workshop-synth-* indices)."
