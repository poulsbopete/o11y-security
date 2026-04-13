#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

require_cmds() {
  local missing=0
  for c in "$@"; do
    if ! command -v "$c" >/dev/null 2>&1; then
      echo "Missing required command: $c" >&2
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    exit 1
  fi
}

load_dotenv() {
  local f="${1:-}"
  if [ -n "$f" ] && [ -f "$f" ]; then
    # If .env still has EC_API_KEY= (empty), do not wipe a key already exported in the shell.
    local saved_ec="${EC_API_KEY-}"
    set -a
    # shellcheck disable=SC1090
    source "$f"
    set +a
    if [ -z "${EC_API_KEY:-}" ] && [ -n "${saved_ec}" ]; then
      EC_API_KEY="${saved_ec}"
      export EC_API_KEY
    fi
  fi
}

require_ec_api_key() {
  if [ -z "${EC_API_KEY:-}" ]; then
    echo "EC_API_KEY is not set (or is empty in .env)." >&2
    echo "  • Edit elastic-agent-builder-a2a-cloud-path/.env and set EC_API_KEY to your Cloud API key." >&2
    echo "  • Create a key: https://cloud.elastic.co/account/keys (Project Admin or Org Owner)." >&2
    echo "  • If the key ends with = or has special characters, wrap it in single quotes in .env." >&2
    exit 1
  fi
}

ec_api() {
  require_ec_api_key
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local url="${EC_BASE_URL:-https://api.elastic-cloud.com}${path}"
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
  local max="${3:-40}"
  local n=0
  while [ "$n" -lt "$max" ]; do
    local resp
    resp="$(ec_api GET "/api/v1/serverless/projects/${kind}/${id}/status")"
    local phase
    phase="$(echo "$resp" | jq -r '.phase // empty')"
    if [ "$phase" = "initialized" ]; then
      echo "${kind} project ${id} is initialized."
      return 0
    fi
    if [ "$phase" = "initializing" ]; then
      echo "Waiting for ${kind} ${id} (${phase})… ($((n + 1))/${max})"
      sleep 15
      n=$((n + 1))
      continue
    fi
    echo "Unexpected phase for ${kind} ${id}: ${phase}" >&2
    echo "$resp" | jq . >&2 || echo "$resp" >&2
    return 1
  done
  echo "Timed out waiting for ${kind} project ${id}." >&2
  return 1
}

# Resolve repo root from this file (lib.sh lives in …/elastic-agent-builder-a2a-cloud-path/scripts).
_LIB_FILE="${BASH_SOURCE[0]}"
repo_root() {
  cd "$(dirname "$_LIB_FILE")/../.." && pwd
}

cloud_path_root() {
  cd "$(dirname "$_LIB_FILE")/.." && pwd
}

workshop_root() {
  echo "$(repo_root)/elastic-agent-builder-a2a-workshop"
}
