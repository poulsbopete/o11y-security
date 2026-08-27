#!/usr/bin/env bash
# Provision Observability + Security Serverless for the Instruqt lab (one VM, two Cloud projects).
# Prefer the image's es3-api.py (same as elastic-autonomous-observability); fall back to Cloud REST.
#
# Requires: ESS_CLOUD_API_KEY (Instruqt secret), curl, jq.
# Skip: A2A_SKIP_CLOUD_PROVISION=1
set -euo pipefail

ROOT="${ELASTIC_WORKSHOP_ROOT:-/root/elastic-workshop}"
STATE="$ROOT/state"
ENV_FILE="$ROOT/.env"
STATUS="$ROOT/provision-status.txt"
LOG="$ROOT/provision.log"
EC_BASE_URL="${EC_BASE_URL:-https://api.elastic-cloud.com}"
REGION="${EC_REGION:-${REGIONS:-aws-us-east-1}}"
REGION="${REGION//_/-}"

mkdir -p "$STATE" "$ROOT"
chmod 700 "$STATE"
umask 077

status() {
  printf '%s\n' "$*" | tee -a "$STATUS" | tee -a "$LOG"
}

: >"$STATUS"
: >"$LOG"
exec > >(tee -a "$LOG") 2>&1

status "[provision] Starting dual Serverless provision at $(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ "${A2A_SKIP_CLOUD_PROVISION:-0}" = "1" ]; then
  status "[provision] Skipped (A2A_SKIP_CLOUD_PROVISION=1)."
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
    status "[provision] .env already complete; rendering proxy."
    bash "$ROOT/scripts/render-kibana-proxy.sh" "$ENV_FILE"
    status "[provision] Ready."
    exit 0
  fi
fi

# --- Resolve Cloud API key (same order as autonomous observability) ---
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
    [ -z "$v" ] && v="$(agent variable get PME_CLOUD_INSTRUQT_API_KEY 2>/dev/null || true)"
    if [ -n "$v" ]; then
      printf '%s' "$v"
      return 0
    fi
  fi
  return 1
}

status "[provision] Resolving ESS_CLOUD_API_KEY…"
status "[provision]   ESS_CLOUD_API_KEY env: ${ESS_CLOUD_API_KEY:+set}${ESS_CLOUD_API_KEY:-not set}"
status "[provision]   PME_CLOUD_INSTRUQT_API_KEY env: ${PME_CLOUD_INSTRUQT_API_KEY:+set}${PME_CLOUD_INSTRUQT_API_KEY:-not set}"

if ! EC_API_KEY="$(resolve_cloud_api_key)"; then
  status "[provision] ERROR: No Cloud API key."
  status "[provision] Fix: Instruqt → Sandbox → Secrets → bind ESS_CLOUD_API_KEY (Org Owner / Project Admin Cloud key)."
  status "[provision] Or BYO: fill $ENV_FILE then: sudo bash $ROOT/scripts/render-kibana-proxy.sh"
  exit 1
fi
export EC_API_KEY
export PME_CLOUD_INSTRUQT_API_KEY="$EC_API_KEY"

for c in curl jq; do
  command -v "$c" >/dev/null 2>&1 || {
    status "[provision] ERROR: missing $c"
    exit 1
  }
done

find_es3_api() {
  local c
  for c in \
    "${PWD}/bin/es3-api.py" \
    "/root/bin/es3-api.py" \
    "/opt/es3-api/bin/es3-api.py" \
    "/home/ubuntu/bin/es3-api.py" \
    "$(command -v es3-api.py 2>/dev/null || true)"; do
    if [ -n "$c" ] && [ -f "$c" ]; then
      printf '%s' "$c"
      return 0
    fi
  done
  # Last resort: search shallow
  c="$(find /root /opt /home -maxdepth 4 -type f -name es3-api.py 2>/dev/null | head -1 || true)"
  if [ -n "$c" ]; then
    printf '%s' "$c"
    return 0
  fi
  return 1
}

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
  # Serverless bootstrap user is often "admin"
  resp="$(curl -sS -u "${user}:${pass}" -X POST "${es_url}/_security/api_key" \
    -H 'Content-Type: application/json' \
    --data-binary "$body")"
  enc="$(echo "$resp" | jq -r '.encoded // empty')"
  if [ -z "$enc" ]; then
    status "[provision] API key create failed for ${es_url}:"
    echo "$resp" | jq . 2>/dev/null || echo "$resp"
    exit 1
  fi
  printf '%s' "$enc"
}

write_env_and_proxy() {
  local o11y_es="$1" o11y_kb="$2" o11y_user="$3" o11y_pass="$4" o11y_id="$5"
  local sec_es="$6" sec_kb="$7" sec_user="$8" sec_pass="$9" sec_id="${10}"
  local o11y_key sec_key

  status "[provision] Creating Elasticsearch API keys…"
  o11y_key="$(mkkey "$o11y_es" "$o11y_user" "$o11y_pass" "a2a-instruqt-o11y")"
  sec_key="$(mkkey "$sec_es" "$sec_user" "$sec_pass" "a2a-instruqt-security")"

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
# Kibana bootstrap admin (lab only)
# Observability: ${o11y_user} / ${o11y_pass}
# Security:      ${sec_user} / ${sec_pass}
# Project ids: o11y=${o11y_id} security=${sec_id}
EOF
  chmod 600 "$ROOT/kibana-login.txt"

  jq -n \
    --arg oid "$o11y_id" --arg oes "$o11y_es" --arg okb "$o11y_kb" --arg ou "$o11y_user" --arg op "$o11y_pass" \
    --arg sid "$sec_id" --arg ses "$sec_es" --arg skb "$sec_kb" --arg su "$sec_user" --arg sp "$sec_pass" \
    '{
      observability: {id:$oid, endpoints:{elasticsearch:$oes, kibana:$okb}, credentials:{username:$ou, password:$op}},
      security: {id:$sid, endpoints:{elasticsearch:$ses, kibana:$skb}, credentials:{username:$su, password:$sp}}
    }' >"$STATE/bootstrap.json"
  chmod 600 "$STATE/bootstrap.json"

  status "[provision] Rendering nginx :8080 / :8081…"
  bash "$ROOT/scripts/render-kibana-proxy.sh" "$ENV_FILE"

  if [ -x "$ROOT/scripts/apply-index-templates.sh" ]; then
    status "[provision] Loading workshop sample data…"
    export ELASTIC_WORKSHOP_ROOT="$ROOT"
    export ELASTIC_WORKSHOP_ENV_FILE="$ENV_FILE"
    bash "$ROOT/scripts/apply-index-templates.sh" || status "[provision] WARN: templates failed"
    bash "$ROOT/scripts/load-sample-bulk.sh" || status "[provision] WARN: bulk failed"
    [ -x "$ROOT/scripts/index-lab-sourcecode.sh" ] && bash "$ROOT/scripts/index-lab-sourcecode.sh" || true
  fi

  status "[provision] DONE. Reload the Serverless Observability / Security tabs."
}

# --- Path A: es3-api.py on the elastic/es3-api-v2 image (preferred) ---
ES3_API=""
if ES3_API="$(find_es3_api)"; then
  status "[provision] Using es3-api.py at ${ES3_API}"
  # Run from the image root that contains bin/ (same as autonomous).
  ES3_HOME="$(cd "$(dirname "$ES3_API")/.." && pwd)"
  stamp="$(date +%s)"
  part="${INSTRUQT_PARTICIPANT_ID:-lab}"
  safe_part="$(printf '%s' "$part" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-' | cut -c1-20)"
  [ -n "$safe_part" ] || safe_part="lab"
  slug="${INSTRUQT_TRACK_SLUG:-a2a}"
  o11y_name="$(printf '%s' "${slug}-o11y-${safe_part}-${stamp}" | cut -c1-48)"
  sec_name="$(printf '%s' "${slug}-sec-${safe_part}-${stamp}" | cut -c1-48)"
  product_tier="${PRODUCT_TIER:-complete}"

  extract_region_field() {
    local file="$1" path="$2"
    local v
    v="$(jq -r --arg r "$REGION" --arg p "$path" '.[$r] | getpath(($p|split("."))) // empty' "$file" 2>/dev/null || true)"
    if [ -z "$v" ]; then
      # Fallback: first top-level key (region id may differ slightly)
      v="$(jq -r --arg p "$path" 'to_entries[0].value | getpath(($p|split("."))) // empty' "$file" 2>/dev/null || true)"
    fi
    printf '%s' "$v"
  }

  status "[provision] Creating Observability project ${o11y_name} (${REGION}) from ${ES3_HOME}…"
  rm -f /tmp/project_results.json
  (
    cd "$ES3_HOME"
    python3 bin/es3-api.py \
      --operation create \
      --project-type observability \
      --product-tier "$product_tier" \
      --regions "$REGION" \
      --project-name "$o11y_name" \
      --api-key "$EC_API_KEY" \
      --wait-for-ready
  )
  if [ ! -f /tmp/project_results.json ]; then
    status "[provision] ERROR: missing /tmp/project_results.json after Observability create"
    exit 1
  fi
  cp /tmp/project_results.json "$STATE/o11y.project_results.json"
  chmod 600 "$STATE/o11y.project_results.json"

  o11y_es="$(extract_region_field "$STATE/o11y.project_results.json" "endpoints.elasticsearch")"
  o11y_kb="$(extract_region_field "$STATE/o11y.project_results.json" "endpoints.kibana")"
  o11y_user="$(extract_region_field "$STATE/o11y.project_results.json" "credentials.username")"
  [ -n "$o11y_user" ] || o11y_user="admin"
  o11y_pass="$(extract_region_field "$STATE/o11y.project_results.json" "credentials.password")"
  o11y_id="$(extract_region_field "$STATE/o11y.project_results.json" "id")"

  status "[provision] Creating Security project ${sec_name} (${REGION})…"
  rm -f /tmp/project_results.json
  (
    cd "$ES3_HOME"
    python3 bin/es3-api.py \
      --operation create \
      --project-type security \
      --regions "$REGION" \
      --project-name "$sec_name" \
      --api-key "$EC_API_KEY" \
      --wait-for-ready
  )
  if [ ! -f /tmp/project_results.json ]; then
    status "[provision] ERROR: missing /tmp/project_results.json after Security create"
    exit 1
  fi
  cp /tmp/project_results.json "$STATE/security.project_results.json"
  chmod 600 "$STATE/security.project_results.json"

  sec_es="$(extract_region_field "$STATE/security.project_results.json" "endpoints.elasticsearch")"
  sec_kb="$(extract_region_field "$STATE/security.project_results.json" "endpoints.kibana")"
  sec_user="$(extract_region_field "$STATE/security.project_results.json" "credentials.username")"
  [ -n "$sec_user" ] || sec_user="admin"
  sec_pass="$(extract_region_field "$STATE/security.project_results.json" "credentials.password")"
  sec_id="$(extract_region_field "$STATE/security.project_results.json" "id")"

  for v in o11y_es o11y_kb o11y_pass o11y_id sec_es sec_kb sec_pass sec_id; do
    if [ -z "${!v}" ]; then
      status "[provision] ERROR: missing ${v} from es3-api results (region=${REGION})"
      status "[provision] O11y JSON keys: $(jq -r 'keys|join(",")' "$STATE/o11y.project_results.json" 2>/dev/null || echo '?')"
      status "[provision] Sec JSON keys: $(jq -r 'keys|join(",")' "$STATE/security.project_results.json" 2>/dev/null || echo '?')"
      exit 1
    fi
  done

  write_env_and_proxy "$o11y_es" "$o11y_kb" "$o11y_user" "$o11y_pass" "$o11y_id" \
    "$sec_es" "$sec_kb" "$sec_user" "$sec_pass" "$sec_id"
  exit 0
fi

# --- Path B: Cloud REST API (fallback when es3-api.py is absent) ---
status "[provision] es3-api.py not found; using Cloud REST API…"

ec_api() {
  local method="$1" path="$2" body="${3:-}"
  local url="${EC_BASE_URL}${path}"
  if [ -n "$body" ]; then
    curl -sS -X "$method" "$url" \
      -H "Authorization: ApiKey ${EC_API_KEY}" \
      -H "Content-Type: application/json" \
      --data-binary "$body"
  else
    curl -sS -X "$method" "$url" -H "Authorization: ApiKey ${EC_API_KEY}"
  fi
}

wait_project() {
  local kind="$1" id="$2" max="${3:-48}" n=0 resp phase
  while [ "$n" -lt "$max" ]; do
    resp="$(ec_api GET "/api/v1/serverless/projects/${kind}/${id}/status")"
    phase="$(echo "$resp" | jq -r '.phase // empty')"
    if [ "$phase" = "initialized" ]; then
      status "[provision] ${kind} ${id} initialized."
      return 0
    fi
    status "[provision] Waiting for ${kind} ${id} (${phase:-unknown})… ($((n + 1))/${max})"
    sleep 15
    n=$((n + 1))
  done
  status "[provision] Timed out waiting for ${kind} ${id}."
  return 1
}

stamp="$(date +%s)"
safe_part="$(printf '%s' "${INSTRUQT_PARTICIPANT_ID:-lab}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-' | cut -c1-24)"
[ -n "$safe_part" ] || safe_part="lab"
o11y_name="$(printf '%s' "a2a-o11y-${safe_part}-${stamp}" | cut -c1-48)"
sec_name="$(printf '%s' "a2a-sec-${safe_part}-${stamp}" | cut -c1-48)"

status "[provision] Creating Observability ${o11y_name}…"
o11y_body="$(jq -n --arg name "$o11y_name" --arg region "$REGION" \
  '{name:$name, region_id:$region, product_tier:"complete"}')"
o11y_resp="$(ec_api POST "/api/v1/serverless/projects/observability" "$o11y_body")"
echo "$o11y_resp" >"$STATE/o11y.create.raw.json"
if ! echo "$o11y_resp" | jq -e '.id' >/dev/null 2>&1; then
  status "[provision] Observability create failed:"
  echo "$o11y_resp" | jq . 2>/dev/null || echo "$o11y_resp"
  exit 1
fi
o11y_id="$(echo "$o11y_resp" | jq -r '.id')"
wait_project "observability" "$o11y_id"

status "[provision] Creating Security ${sec_name}…"
sec_body="$(jq -n --arg name "$sec_name" --arg region "$REGION" '{name:$name, region_id:$region}')"
sec_resp="$(ec_api POST "/api/v1/serverless/projects/security" "$sec_body")"
echo "$sec_resp" >"$STATE/security.create.raw.json"
if ! echo "$sec_resp" | jq -e '.id' >/dev/null 2>&1; then
  status "[provision] Security create failed:"
  echo "$sec_resp" | jq . 2>/dev/null || echo "$sec_resp"
  exit 1
fi
sec_id="$(echo "$sec_resp" | jq -r '.id')"
wait_project "security" "$sec_id"

# Re-fetch full project docs for endpoints (create response may already include them)
o11y_es="$(echo "$o11y_resp" | jq -r '.endpoints.elasticsearch // empty')"
o11y_kb="$(echo "$o11y_resp" | jq -r '.endpoints.kibana // empty')"
o11y_user="$(echo "$o11y_resp" | jq -r '.credentials.username // "admin"')"
o11y_pass="$(echo "$o11y_resp" | jq -r '.credentials.password // empty')"
sec_es="$(echo "$sec_resp" | jq -r '.endpoints.elasticsearch // empty')"
sec_kb="$(echo "$sec_resp" | jq -r '.endpoints.kibana // empty')"
sec_user="$(echo "$sec_resp" | jq -r '.credentials.username // "admin"')"
sec_pass="$(echo "$sec_resp" | jq -r '.credentials.password // empty')"

write_env_and_proxy "$o11y_es" "$o11y_kb" "$o11y_user" "$o11y_pass" "$o11y_id" \
  "$sec_es" "$sec_kb" "$sec_user" "$sec_pass" "$sec_id"
