#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_cmds curl jq bash

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WS="$(workshop_root)"
ENVF="$ROOT/state/workshop.env"
if [ ! -f "$ENVF" ]; then
  echo "Missing ${ENVF} — run 02-create-es-api-keys.sh first." >&2
  exit 1
fi

export ELASTIC_WORKSHOP_ROOT="$WS"
export ELASTIC_WORKSHOP_ENV_FILE="$ENVF"

bash "$WS/scripts/apply-index-templates.sh"
bash "$WS/scripts/load-sample-bulk.sh"

echo "Templates + synthetic bulk data loaded using workshop scripts."
