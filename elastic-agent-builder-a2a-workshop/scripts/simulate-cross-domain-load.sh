#!/usr/bin/env bash
# Simulate correlated load across Security + Observability clusters:
#   Security: burst of failed authentication events (workshop-synth-endpoint-alerts)
#   Observability: high CPU/memory metrics + failed traces (same host.name) on workshop-synth-*
#
# Uses the same credentials as load-sample-bulk.sh (ELASTIC_WORKSHOP_ENV_FILE).
#
# Environment (all optional):
#   SIMULATE_ROUNDS       — iterations (default: 15)
#   SIMULATE_BURST_SIZE   — docs per index per round, per cluster (default: 12)
#   SIMULATE_SLEEP_SEC    — pause between rounds (default: 1)
#   SIMULATE_HOST         — host.name / host.name (default: prod-db-01)
#   SIMULATE_SERVICE      — APM service name in traces (default: inventory-api)
#   SIMULATE_DRY_RUN      — if 1, print sizes only, no POST
#
# Example (from repo root, after workshop.env exists):
#   export ELASTIC_WORKSHOP_ROOT="$(pwd)/elastic-agent-builder-a2a-workshop"
#   export ELASTIC_WORKSHOP_ENV_FILE="$(pwd)/elastic-agent-builder-a2a-cloud-path/state/workshop.env"
#   SIMULATE_ROUNDS=30 SIMULATE_BURST_SIZE=20 bash "$ELASTIC_WORKSHOP_ROOT/scripts/simulate-cross-domain-load.sh"
set -euo pipefail

ROOT="${ELASTIC_WORKSHOP_ROOT:-/root/elastic-workshop}"
ENV_FILE="${ELASTIC_WORKSHOP_ENV_FILE:-$ROOT/.env}"
if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE — set ELASTIC_WORKSHOP_ENV_FILE (e.g. cloud-path/state/workshop.env)." >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

for v in SECURITY_ES_URL SECURITY_API_KEY O11Y_ES_URL O11Y_API_KEY; do
  if [ -z "${!v:-}" ]; then
    echo "Missing ${v} in ${ENV_FILE}" >&2
    exit 1
  fi
done

ROUNDS="${SIMULATE_ROUNDS:-15}"
BURST="${SIMULATE_BURST_SIZE:-12}"
SLEEP="${SIMULATE_SLEEP_SEC:-1}"
HOST="${SIMULATE_HOST:-prod-db-01}"
SERVICE="${SIMULATE_SERVICE:-inventory-api}"
DRY="${SIMULATE_DRY_RUN:-0}"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '1,35p' "$0"
  exit 0
fi

for c in curl jq; do
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "Missing required command: $c" >&2
    exit 1
  fi
done

ST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/workshop-sim.XXXXXX")"
trap 'rm -rf "$ST_DIR"' EXIT

bulk_ndjson() {
  local url="$1"
  local key="$2"
  local file="$3"
  if [ "$DRY" = "1" ]; then
    echo "[dry-run] would POST _bulk ($(wc -c <"$file") bytes) to ${url}"
    return 0
  fi
  local resp
  resp="$(curl -sS -X POST "${url}/_bulk" \
    -H "Authorization: ApiKey ${key}" \
    -H "Content-Type: application/x-ndjson" \
    --data-binary "@${file}")"
  if ! echo "$resp" | jq -e '.errors == false' >/dev/null 2>&1; then
    echo "_bulk reported errors:" >&2
    echo "$resp" | jq . >&2 2>/dev/null || echo "$resp" >&2
    return 1
  fi
}

write_security_burst() {
  local out="$1"
  local ts="$2"
  local n="$3"
  : >"$out"
  local i oct
  for i in $(seq 1 "$n"); do
    oct=$((20 + (i % 200)))
    printf '%s\n' '{"index":{"_index":"workshop-synth-endpoint-alerts"}}' >>"$out"
    jq -c -n \
      --arg ts "$ts" \
      --arg host "$HOST" \
      --arg user "svc-loadtest" \
      --argjson ip_last "$oct" \
      --arg msg "simulated auth failure burst $i" \
      '{
        "@timestamp": $ts,
        "host": {"name": $host},
        "event": {"category": ["authentication"], "outcome": "failure", "type": ["start"]},
        "user": {"name": $user},
        "source": {"ip": ("198.51.100." + ($ip_last | tostring))},
        "message": $msg
      }' >>"$out"
  done
}

write_o11y_burst() {
  local out="$1"
  local ts="$2"
  local n="$3"
  : >"$out"
  local i cpu mem dur outcome code
  for i in $(seq 1 "$n"); do
    cpu="$(awk "BEGIN {printf \"%.2f\", 0.75 + ($i % 5) * 0.04}")"
    mem="$(awk "BEGIN {printf \"%.2f\", 0.70 + ($i % 4) * 0.05}")"
    printf '%s\n' '{"index":{"_index":"workshop-synth-metrics"}}' >>"$out"
    jq -c -n \
      --arg ts "$ts" \
      --arg host "$HOST" \
      --argjson cpu "$cpu" \
      --argjson mem "$mem" \
      --argjson disk "$((104857600 + i * 1024000))" \
      '{
        "@timestamp": $ts,
        "host.name": $host,
        "system.cpu.total.norm.pct": ($cpu | tonumber),
        "system.memory.actual.used.pct": ($mem | tonumber),
        "system.diskio.read.bytes": ($disk | tonumber)
      }' >>"$out"

    if (( i % 3 == 0 )); then
      outcome="failure"
      code=500
      dur=$((1800000 + i * 10000))
    else
      outcome="success"
      code=200
      dur=$((400000 + i * 5000))
    fi
    printf '%s\n' '{"index":{"_index":"workshop-synth-traces"}}' >>"$out"
    jq -c -n \
      --arg ts "$ts" \
      --arg host "$HOST" \
      --arg svc "$SERVICE" \
      --arg oc "$outcome" \
      --argjson code "$code" \
      --argjson dur "$dur" \
      '{
        "@timestamp": $ts,
        "service": {"name": $svc},
        "host": {"name": $host},
        "transaction": {"duration": {"us": $dur}},
        "event": {"outcome": $oc},
        "http": {"response": {"status_code": $code}}
      }' >>"$out"
  done
}

echo "Cross-domain load simulation"
echo "  Security ES:    ${SECURITY_ES_URL}"
echo "  Observability:  ${O11Y_ES_URL}"
echo "  Rounds=${ROUNDS} burst=${BURST} sleep=${SLEEP}s host=${HOST} dry_run=${DRY}"
echo ""

r=1
while [ "$r" -le "$ROUNDS" ]; do
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  sec_f="${ST_DIR}/sec-${r}.ndjson"
  o11y_f="${ST_DIR}/o11y-${r}.ndjson"
  write_security_burst "$sec_f" "$ts" "$BURST"
  write_o11y_burst "$o11y_f" "$ts" "$BURST"

  echo "Round ${r}/${ROUNDS} @ ${ts} — posting Security (${BURST} auth failures) + Observability (${BURST} metrics + ${BURST} traces, failures every 3rd) in parallel…"

  if [ "$DRY" = "1" ]; then
    bulk_ndjson "$SECURITY_ES_URL" "$SECURITY_API_KEY" "$sec_f" &
    bulk_ndjson "$O11Y_ES_URL" "$O11Y_API_KEY" "$o11y_f" &
    wait
  else
    bulk_ndjson "$SECURITY_ES_URL" "$SECURITY_API_KEY" "$sec_f" &
    pid1=$!
    bulk_ndjson "$O11Y_ES_URL" "$O11Y_API_KEY" "$o11y_f" &
    pid2=$!
    s1=0
    s2=0
    wait "$pid1" || s1=$?
    wait "$pid2" || s2=$?
    if [ "$s1" -ne 0 ] || [ "$s2" -ne 0 ]; then
      echo "Round $r failed (Security exit=$s1 Observability exit=$s2)." >&2
      exit 1
    fi
  fi

  r=$((r + 1))
  if [ "$r" -le "$ROUNDS" ]; then
    sleep "$SLEEP"
  fi
done

echo ""
echo "Done. Query examples (Dev Tools / ES|QL):"
echo "  Security:   FROM workshop-synth-endpoint-alerts | WHERE host.name == \"${HOST}\" | STATS c = COUNT(*) BY @timestamp | SORT @timestamp DESC | LIMIT 20"
echo "  Metrics:    FROM workshop-synth-metrics | WHERE host.name == \"${HOST}\" | STATS max_cpu = MAX(system.cpu.total.norm.pct) BY @timestamp | SORT @timestamp DESC | LIMIT 20"
echo "  Traces:     FROM workshop-synth-traces | WHERE host.name == \"${HOST}\" AND event.outcome == \"failure\" | STATS fails = COUNT(*) | LIMIT 10"
echo ""
echo "Note: ES|QL and Dev Tools searches do **not** create Kibana **alerting** alerts or run alert-triggered **Workflows**."
echo "For lab rules on workshop indices, use cloud-path **scripts/07-lab-alert-rules.sh** (Observability rules use consumer **observability** so matches show under **Observability → Alerts**)."
echo "Re-attach **Workflow** actions on a rule after **07** if it recreated the rule. More ingest: **scripts/10-lab-simulate-traffic.sh**; instant workflow test: **scripts/08-synthetic-workflow-test.sh**."
