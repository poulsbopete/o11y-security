#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "== A2A cloud path: provision → API keys → populate =="
bash "$SCRIPT_DIR/00-check-prereqs.sh"
bash "$SCRIPT_DIR/01-provision-serverless.sh"
bash "$SCRIPT_DIR/02-create-es-api-keys.sh"
bash "$SCRIPT_DIR/03-populate-indices.sh"
bash "$SCRIPT_DIR/04-print-next-steps.sh"
echo "Done."
