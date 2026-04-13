#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/elastic-workshop"
ENV_FILE="$ROOT/.env"
# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

bulk() {
  local url="$1"
  local key="$2"
  local file="$3"
  curl -sS -X POST "${url}/_bulk" \
    -H "Authorization: Bearer ${key}" \
    -H "Content-Type: application/x-ndjson" \
    --data-binary "@${file}" | jq -e '.errors == false' >/dev/null
}

bulk "$SECURITY_ES_URL" "$SECURITY_API_KEY" "$ROOT/sample-data/endpoint-alerts.ndjson"
bulk "$O11Y_ES_URL" "$O11Y_API_KEY" "$ROOT/sample-data/metrics-host.ndjson"
bulk "$O11Y_ES_URL" "$O11Y_API_KEY" "$ROOT/sample-data/traces-apm.ndjson"

echo "Sample bulk loads completed (workshop-synth-* indices)."
