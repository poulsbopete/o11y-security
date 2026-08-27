#!/usr/bin/env bash
# Provision Observability + Security Serverless projects for the Instruqt lab,
# mint Elasticsearch API keys, write /root/elastic-workshop/.env, and render nginx.
#
# Requires: ESS_CLOUD_API_KEY (Instruqt secret), curl, jq.
# Skip: A2A_SKIP_CLOUD_PROVISION=1
# Reuse existing projects: leave a valid .env in place (this script no-ops if both Kibana URLs are set).
set -euo pipefail

ROOT="${ELASTIC_WORKSHOP_ROOT:-/root/elastic-workshop}"
STATE="$ROOT/state"
ENV_FILE="$ROOT/.env"
EC_BASE_URL="${EC_BASE_URL:-https://api.elastic-cloud.com}"
REGION="${EC_REGION:-${REGIONS:-aws-us-east-1}}"
# Cloud API region_id uses dashes (e.g. aws-us-east-1); normalize underscore form.
REGION="${REGION//_/-}"

if [ "${A2A_SKIP_CLOUD_PROVISION:-0}" = "1" ]; then
  echo "[provision] Skipping Cloud provision (A2A_SKIP_CLOUD_PROVISION=1)."
  exit 0
fi

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  if [ -n "${O11Y_KIBANA_URL:-}" ] && [ -n "${SECURITY_KIBANA_URL:-}" ] \
    && [ -n "${O11Y_ES_URL:-}" ] && [ -n "${SECURITY_ES_URL:-}" ] \
    && [ -n "${O11Y_API_KEY:-}" ] && [ -n "${SECURITY_API_KEY:-}" ]; then
    echo "[provision] .env already has both projects; rendering proxy only."
    bash "$ROOT/scripts/render-kibana-proxy.sh" "$ENV_FILE" || true
    exit 0
  fi
fi

resolve_cloud_api_key() {
  if [ -n "${PME_CLOUD_INSTRUQT_API_KEY:-}" ]; then
    printf '%s' "$PME_CLOUD_INSTRUQT_API_KEY"
    return 0
  fi
  if [ -n "${ESS_CLOUD_API_KEY:-}" ]; then
    printf '%s' "$ESS_CLOUD_API_KEY"
    return 0
  fi
  if [ -n "${EC_API_KEY:-}" ]; then
    printf '%s' "$EC_API_KEY"
    return 0
  fi
  if command -v agent >/dev/null 2>&1; then
    local v
    v="$(agent variable get ESS_CLOUD_API_KEY 2>/dev/null || true)"
    if [ -n "$v" ]; then
      printf '%s' "$v"
      return 0
    fi
  fi
  return 1
}

EC_API_KEY="$(resolve_cloud_api_key)" || {
  echo "[provision] No ESS_CLOUD_API_KEY (or PME_CLOUD_INSTRUQT_API_KEY / EC_API_KEY)." >&2
  echo "[provision] Add the secret under Instruqt Sandbox → Secrets, or BYO: fill .env and run render-kibana-proxy.sh." >&2
  exit 1
}
export EC_API_KEY

for c in curl jq; do
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "[provision] Missing required command: $c" >&2
    exit 1
  fi
done

mkdir -p "$STATE"
chmod 700 "$STATE"

ec_api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local url="${EC_BASE_URL}${path}"
  if [ -n "$body" ]; then
    curl -sS -X "$method" "$url" \
      -H "Authorization: ApiKey ${EC_API_KEY}" \
      -H "Content-Type: application/json" \
      --data-binary "$body"
  else
    curl -sS -X "$method" "$url" \
      -H "Authorization: ApiKey ${EC_API_KEY}"
  fi
}

wait_project() {
  local kind="$1"
  local id="$2"
  local max="${3:-48}"
  local n=0
  local resp phase
  while [ "$n" -lt "$max" ]; do
    resp="$(ec_api GET "/api/v1/serverless/projects/${kind}/${id}/status")"
    phase="$(echo "$resp" | jq -r '.phase // empty')"
    if [ "$phase" = "initialized" ]; then
      echo "[provision] ${kind} ${id} initialized."
      return 0
    fi
    echo "[provision] Waiting for ${kind} ${id} (${phase:-unknown})… ($((n + 1))/${max})"
    sleep 15
    n=$((n + 1))
  done
  echo "[provision] Timed out waiting for ${kind} ${id}." >&2
  return 1
}

stamp="$(date +%s)"
slug="${INSTRUQT_TRACK_SLUG:-a2a}"
part="${INSTRUQT_PARTICIPANT_ID:-lab}"
# RFC1035-ish: lowercase, hyphens only
safe_part="$(printf '%s' "$part" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-' | cut -c1-24)"
[ -n "$safe_part" ] || safe_part="lab"
o11y_name="a2a-o11y-${safe_part}-${stamp}"
sec_name="a2a-sec-${safe_part}-${stamp}"
# Cap length for Cloud naming
o11y_name="$(printf '%s' "$o11y_name" | cut -c1-48)"
sec_name="$(printf '%s' "$sec_name" | cut -c1-48)"

echo "[provision] Creating Observability project ${o11y_name} in ${REGION}…"
o11y_body="$(jq -n --arg name "$o11y_name" --arg region "$REGION" \
  '{name:$name, region_id:$region, product_tier:"complete"}')"
o11y_resp="$(ec_api POST "/api/v1/serverless/projects/observability" "$o11y_body")"
if ! echo "$o11y_resp" | jq -e '.id' >/dev/null 2>&1; then
  echo "[provision] Observability create failed:" >&2
  echo "$o11y_resp" | jq . >&2 2>/dev/null || echo "$o11y_resp" >&2
  exit 1
fi
o11y_id="$(echo "$o11y_resp" | jq -r '.id')"
umask 077
echo "$o11y_resp" >"$STATE/o11y.create.raw.json"
wait_project "observability" "$o11y_id"

echo "[provision] Creating Security project ${sec_name} in ${REGION}…"
sec_body="$(jq -n --arg name "$sec_name" --arg region "$REGION" '{name:$name, region_id:$region}')"
sec_resp="$(ec_api POST "/api/v1/serverless/projects/security" "$sec_body")"
if ! echo "$sec_resp" | jq -e '.id' >/dev/null 2>&1; then
  echo "[provision] Security create failed:" >&2
  echo "$sec_resp" | jq . >&2 2>/dev/null || echo "$sec_resp" >&2
  exit 1
fi
sec_id="$(echo "$sec_resp" | jq -r '.id')"
echo "$sec_resp" >"$STATE/security.create.raw.json"
wait_project "security" "$sec_id"

jq -n \
  --argjson o11y "$(echo "$o11y_resp" | jq '{id,name,region_id,endpoints,credentials}')" \
  --argjson sec "$(echo "$sec_resp" | jq '{id,name,region_id,endpoints,credentials}')" \
  '{observability:$o11y, security:$sec}' >"$STATE/bootstrap.json"
chmod 600 "$STATE/bootstrap.json"

o11y_es="$(jq -r '.observability.endpoints.elasticsearch // empty' "$STATE/bootstrap.json")"
o11y_kb="$(jq -r '.observability.endpoints.kibana // empty' "$STATE/bootstrap.json")"
o11y_user="$(jq -r '.observability.credentials.username // empty' "$STATE/bootstrap.json")"
o11y_pass="$(jq -r '.observability.credentials.password // empty' "$STATE/bootstrap.json")"
sec_es="$(jq -r '.security.endpoints.elasticsearch // empty' "$STATE/bootstrap.json")"
sec_kb="$(jq -r '.security.endpoints.kibana // empty' "$STATE/bootstrap.json")"
sec_user="$(jq -r '.security.credentials.username // empty' "$STATE/bootstrap.json")"
sec_pass="$(jq -r '.security.credentials.password // empty' "$STATE/bootstrap.json")"

for v in o11y_es o11y_kb o11y_user o11y_pass sec_es sec_kb sec_user sec_pass; do
  if [ -z "${!v}" ]; then
    echo "[provision] Missing ${v} in bootstrap.json." >&2
    exit 1
  fi
done

mkkey() {
  local es_url="$1" user="$2" pass="$3" name="$4"
  local body resp enc
  body="$(jq -n --arg n "$name" '{
    name: $n,
    role_descriptors: {
      a2a_workshop: {
        cluster: ["monitor", "manage_index_templates"],
        indices: [{ names: ["*", ".*"], privileges: ["all"] }]
      }
    }
  }')"
  resp="$(curl -sS -u "${user}:${pass}" -X POST "${es_url}/_security/api_key" \
    -H 'Content-Type: application/json' \
    --data-binary "$body")"
  enc="$(echo "$resp" | jq -r '.encoded // empty')"
  if [ -z "$enc" ]; then
    echo "[provision] API key create failed for ${es_url}:" >&2
    echo "$resp" | jq . >&2 2>/dev/null || echo "$resp" >&2
    exit 1
  fi
  printf '%s' "$enc"
}

echo "[provision] Creating Elasticsearch API keys…"
o11y_key="$(mkkey "$o11y_es" "$o11y_user" "$o11y_pass" "a2a-instruqt-o11y")"
sec_key="$(mkkey "$sec_es" "$sec_user" "$sec_pass" "a2a-instruqt-security")"

umask 077
cat >"$ENV_FILE" <<EOF
O11Y_ES_URL=${o11y_es}
O11Y_API_KEY=${o11y_key}
O11Y_KIBANA_URL=${o11y_kb}
SECURITY_ES_URL=${sec_es}
SECURITY_API_KEY=${sec_key}
SECURITY_KIBANA_URL=${sec_kb}
O11Y_AGENT_ENDPOINT=${o11y_kb%/}/api/agent_builder/converse
SECURITY_AGENT_ENDPOINT=${sec_kb%/}/api/agent_builder/converse
EOF
chmod 600 "$ENV_FILE"

cat >"$ROOT/kibana-login.txt" <<EOF
# Kibana bootstrap admin (lab only — do not commit)
# Observability: ${o11y_user} / ${o11y_pass}
# Security:      ${sec_user} / ${sec_pass}
# Project ids: o11y=${o11y_id} security=${sec_id}
EOF
chmod 600 "$ROOT/kibana-login.txt"

echo "[provision] Wrote ${ENV_FILE} and ${ROOT}/kibana-login.txt"
bash "$ROOT/scripts/render-kibana-proxy.sh" "$ENV_FILE"

# Seed workshop indices so later challenges have data immediately.
if [ -x "$ROOT/scripts/apply-index-templates.sh" ] && [ -x "$ROOT/scripts/load-sample-bulk.sh" ]; then
  echo "[provision] Loading workshop templates + sample data…"
  export ELASTIC_WORKSHOP_ROOT="$ROOT"
  export ELASTIC_WORKSHOP_ENV_FILE="$ENV_FILE"
  bash "$ROOT/scripts/apply-index-templates.sh" || echo "[provision] WARN: apply-index-templates failed"
  bash "$ROOT/scripts/load-sample-bulk.sh" || echo "[provision] WARN: load-sample-bulk failed"
  if [ -x "$ROOT/scripts/index-lab-sourcecode.sh" ]; then
    bash "$ROOT/scripts/index-lab-sourcecode.sh" || echo "[provision] WARN: index-lab-sourcecode failed"
  fi
fi

echo "[provision] Dual Serverless projects ready. Reload the Kibana tabs."
