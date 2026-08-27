#!/usr/bin/env bash
# Start (or restart) the lab Chaos Console on port 8082.
set -euo pipefail

ROOT="${ELASTIC_WORKSHOP_ROOT:-/root/elastic-workshop}"
APP="$ROOT/lab-app/chaos_ui.py"
PORT="${CHAOS_UI_PORT:-8082}"
LOG="${CHAOS_UI_LOG:-/tmp/chaos-ui.log}"
PIDF="${CHAOS_UI_PID:-/tmp/chaos-ui.pid}"

if [ ! -f "$APP" ]; then
  echo "Missing $APP — sync lab-app from the track (challenge setup) first." >&2
  exit 1
fi

if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo "Chaos Console already running (pid $(cat "$PIDF")) on port ${PORT}."
  exit 0
fi

export ELASTIC_WORKSHOP_ROOT="$ROOT"
nohup python3 "$APP" >>"$LOG" 2>&1 &
echo $! >"$PIDF"
sleep 0.4
if kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo "Chaos Console started pid $(cat "$PIDF") — http://0.0.0.0:${PORT}/ (log ${LOG})"
else
  echo "Chaos Console failed to start; see ${LOG}" >&2
  exit 1
fi
