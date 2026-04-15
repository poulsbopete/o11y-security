#!/usr/bin/env bash
# Push **synthetic workshop documents** into `workshop-synth-*` on Security + Observability
# Elasticsearch endpoints (same as `simulate-cross-domain-load.sh` in the workshop repo).
#
# Why this exists
# -------------
# **Kibana alerting** creates alerts when **rules** evaluate against **Elasticsearch** (e.g. your
# lab `.es-query` rules from **07**). More matching docs ⇒ new rule runs ⇒ **Workflow** actions fire
# if you attached them on the rule.
#
# **Running a workflow from the UI (Run)** calls **`/api/workflows/test`** with optional inputs.
# That exercises the workflow (and can create Cases if the YAML includes `createCase`) but it does
# **not** create a row in **Stack Management → Rules** “recent alerts” the same way a real rule
# evaluation does. For that, use this script (ingest) or wait for the rule schedule on existing data.
#
# For an immediate **workflow** smoke test without ingest, use **08** (`scripts/08-synthetic-workflow-test.sh`).
#
# Environment (optional — passed through to the workshop script):
#   SIMULATE_ROUNDS, SIMULATE_BURST_SIZE, SIMULATE_SLEEP_SEC, SIMULATE_HOST, SIMULATE_SERVICE, SIMULATE_DRY_RUN
#
# Requires: state/workshop.env (from **02-create-es-api-keys.sh**), workshop repo beside cloud-path.
# Skip: A2A_SKIP_LAB_SIMULATE_TRAFFIC=1
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

load_dotenv "$ROOT/.env"

if [ "${A2A_SKIP_LAB_SIMULATE_TRAFFIC:-0}" = "1" ]; then
  echo "Skipping lab traffic simulation (A2A_SKIP_LAB_SIMULATE_TRAFFIC=1)."
  exit 0
fi

ENVF="$ROOT/state/workshop.env"
if [ ! -f "$ENVF" ]; then
  echo "Missing ${ENVF} — run scripts/02-create-es-api-keys.sh first." >&2
  exit 1
fi

WS="$(workshop_root)"
SIM="$WS/scripts/simulate-cross-domain-load.sh"
if [ ! -f "$SIM" ]; then
  echo "Missing ${SIM} — workshop repo should live next to cloud-path (see scripts/lib.sh workshop_root)." >&2
  exit 1
fi

require_cmds bash jq curl

export ELASTIC_WORKSHOP_ROOT="$WS"
export ELASTIC_WORKSHOP_ENV_FILE="$ENVF"

echo "== Lab simulate traffic → workshop-synth-* (Security + Observability) =="
echo "Using ELASTIC_WORKSHOP_ROOT=${ELASTIC_WORKSHOP_ROOT}"
echo "Using ELASTIC_WORKSHOP_ENV_FILE=${ELASTIC_WORKSHOP_ENV_FILE}"
echo "Tip: lab rules from **07** run every **1m**; after this finishes, check **Stack Management → Rules**"
echo "     (tag **a2a-lab**) and **Observability → Alerts** for new activity."
echo ""

bash "$SIM"

echo ""
echo "Done. Optional: bash ${ROOT}/scripts/08-synthetic-workflow-test.sh  (workflow + case without waiting on rules)"
