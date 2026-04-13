#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/elastic-workshop"
ENV_FILE="$ROOT/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE — copy assets/env.template first."
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

apply() {
  local base_url="$1"
  local api_key="$2"
  local name="$3"
  local file="$ROOT/indices/${name}.json"
  if [ ! -f "$file" ]; then
    echo "Missing template file: $file"
    exit 1
  fi
  curl -sS -X PUT "${base_url}/_index_template/${name}" \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    --data-binary "@${file}"
}

apply "$SECURITY_ES_URL" "$SECURITY_API_KEY" "security-detections-template"
apply "$SECURITY_ES_URL" "$SECURITY_API_KEY" "security-a2a-enriched-template"
apply "$SECURITY_ES_URL" "$SECURITY_API_KEY" "response-log-template"

echo "Index templates applied on Security cluster."
