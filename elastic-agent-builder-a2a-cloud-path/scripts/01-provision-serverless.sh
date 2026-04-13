#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_cmds curl jq

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
load_dotenv "$ROOT/.env"

mkdir -p "$ROOT/state"
stamp="$(date +%s)"
prefix="${A2A_NAME_PREFIX:-a2a-lab}"
region="${EC_REGION:-gcp-us-central1}"
o11y_name="${prefix}-o11y-${stamp}"
sec_name="${prefix}-sec-${stamp}"

echo "Creating Observability project: ${o11y_name} (${region})"
o11y_body="$(jq -n --arg name "$o11y_name" --arg region "$region" \
  '{name:$name, region_id:$region, product_tier:"complete"}')"
o11y_resp="$(ec_api POST "/api/v1/serverless/projects/observability" "$o11y_body")"
if ! echo "$o11y_resp" | jq -e '.id' >/dev/null 2>&1; then
  echo "Observability project create failed:" >&2
  echo "$o11y_resp" | jq . >&2 2>/dev/null || echo "$o11y_resp" >&2
  exit 1
fi
echo "$o11y_resp" >"$ROOT/state/o11y.create.raw.json"
chmod 600 "$ROOT/state/o11y.create.raw.json"
o11y_id="$(echo "$o11y_resp" | jq -r '.id')"
echo "$o11y_resp" | jq 'del(.credentials)' >"$ROOT/state/o11y.public.json"
wait_project "observability" "$o11y_id"

echo "Creating Security project: ${sec_name} (${region})"
sec_body="$(jq -n --arg name "$sec_name" --arg region "$region" '{name:$name, region_id:$region}')"
sec_resp="$(ec_api POST "/api/v1/serverless/projects/security" "$sec_body")"
if ! echo "$sec_resp" | jq -e '.id' >/dev/null 2>&1; then
  echo "Security project create failed:" >&2
  echo "$sec_resp" | jq . >&2 2>/dev/null || echo "$sec_resp" >&2
  exit 1
fi
echo "$sec_resp" >"$ROOT/state/security.create.raw.json"
chmod 600 "$ROOT/state/security.create.raw.json"
sec_id="$(echo "$sec_resp" | jq -r '.id')"
echo "$sec_resp" | jq 'del(.credentials)' >"$ROOT/state/security.public.json"
wait_project "security" "$sec_id"

jq -n \
  --argjson o11y "$(echo "$o11y_resp" | jq '{id,name,region_id,endpoints,credentials}')" \
  --argjson sec "$(echo "$sec_resp" | jq '{id,name,region_id,endpoints,credentials}')" \
  '{observability:$o11y, security:$sec}' >"$ROOT/state/bootstrap.json"
chmod 600 "$ROOT/state/bootstrap.json"

echo
echo "Provisioned projects (details without passwords in state/*.public.json)."
echo "  Observability id: ${o11y_id}"
echo "  Security id:      ${sec_id}"
echo "Bootstrap file: ${ROOT}/state/bootstrap.json (600) — contains admin credentials for API key minting only."
