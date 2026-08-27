#!/usr/bin/env bash
# Index lab source into Observability Elasticsearch.
#
# Always: bulk-index lab-app files → workshop-synth-sourcecode (Sourcerer-like, no extra deps).
# Optional: install + run https://github.com/elastic/sourcerer against poulsbopete/o11y-security
#           when uv is available and A2A_SKIP_SOURCERER is not 1.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
load_dotenv "$ROOT/.env"

WS="$(workshop_root)"
ENVF="$ROOT/state/workshop.env"
if [ ! -f "$ENVF" ]; then
  echo "Missing ${ENVF} — run 02-create-es-api-keys.sh first." >&2
  exit 1
fi

export ELASTIC_WORKSHOP_ROOT="$WS"
export ELASTIC_WORKSHOP_ENV_FILE="$ENVF"

echo "== Lab source index (workshop-synth-sourcecode) =="
bash "$WS/scripts/index-lab-sourcecode.sh"

if [ "${A2A_SKIP_SOURCERER:-0}" = "1" ]; then
  echo "Skipping Sourcerer CLI (A2A_SKIP_SOURCERER=1)."
  exit 0
fi

# shellcheck disable=SC1090
set -a
source "$ENVF"
set +a

BOOT="$ROOT/state/bootstrap.json"
if [ ! -f "$BOOT" ]; then
  echo "WARN: no bootstrap.json — cannot wire Sourcerer Kibana URL. Lab index is still loaded." >&2
  exit 0
fi

o11y_kb="$(jq -r '.observability.endpoints.kibana // empty' "$BOOT")"
if [ -z "${O11Y_ES_URL:-}" ] || [ -z "${O11Y_API_KEY:-}" ] || [ -z "$o11y_kb" ]; then
  echo "WARN: Observability ES/Kibana not fully set — skip Sourcerer CLI." >&2
  exit 0
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "Sourcerer CLI skipped: install uv (https://docs.astral.sh/uv/) then re-run this script."
  echo "  uv tool install \"git+https://github.com/elastic/sourcerer.git@v3.0.2\""
  exit 0
fi

if ! command -v sourcerer >/dev/null 2>&1; then
  echo "Installing Sourcerer CLI (pinned v3.0.2)…"
  uv tool install "git+https://github.com/elastic/sourcerer.git@v3.0.2"
fi

WORKDIR="$ROOT/state/sourcerer"
mkdir -p "$WORKDIR"
umask 077
cat >"$WORKDIR/.env" <<EOF
ELASTICSEARCH_URL=${O11Y_ES_URL}
KIBANA_URL=${o11y_kb}
ELASTICSEARCH_API_KEY=${O11Y_API_KEY}
EOF
cp "$ROOT/sourcerer.yml" "$WORKDIR/sourcerer.yml"

echo "== Sourcerer setup + index (Observability cluster) =="
(
  cd "$WORKDIR"
  sourcerer setup --config sourcerer.yml
  sourcerer index --config sourcerer.yml
)

echo "Sourcerer finished. In Observability Kibana → Agents, open the Sourcerer agent (or lab context agent) and ask:"
echo "  Where is LAB_VULN:sql_injection in the claims portal?"
echo "  Cite file.path and recommend a parameterized query."
