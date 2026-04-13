#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_cmds curl jq

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
load_dotenv "$ROOT/.env"

if [ -z "${EC_API_KEY:-}" ]; then
  echo "Set EC_API_KEY in ${ROOT}/.env (see env.example)." >&2
  echo "Follow the Elastic cloud-setup skill: https://cloud.elastic.co/account/keys" >&2
  exit 1
fi

if curl -sf -H "Authorization: ApiKey ${EC_API_KEY}" \
  "${EC_BASE_URL:-https://api.elastic-cloud.com}/api/v1/serverless/regions" >/dev/null; then
  echo "EC_API_KEY validates against ${EC_BASE_URL:-https://api.elastic-cloud.com}."
else
  echo "EC_API_KEY failed regions check." >&2
  exit 1
fi

echo "Prereqs OK."
