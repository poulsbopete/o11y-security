#!/usr/bin/env bash
# Shared helpers for Instruqt challenge scripts.

workshop_root() {
  echo "/root/elastic-workshop"
}

# Pass "${BASH_SOURCE[0]}" from the calling setup/check/solve script.
track_root_from_challenge_script() {
  local origin="$1"
  local script_dir
  script_dir="$(cd "$(dirname "$origin")" && pwd)"
  if [ -f "$script_dir/../track.yml" ]; then
    cd "$script_dir/.." && pwd
    return 0
  fi
  echo ""
}

sync_track_assets() {
  local origin="$1"
  local tr
  tr="$(track_root_from_challenge_script "$origin")"
  if [ -z "$tr" ]; then
    echo "[workshop] WARN: could not resolve track root; skipping asset sync"
    return 0
  fi
  mkdir -p "$(workshop_root)"/{assets,agent-scaffolds,scripts,sample-data,indices}
  [ -d "$tr/sample-data" ] && cp -a "$tr/sample-data/." "$(workshop_root)/sample-data/"
  [ -d "$tr/indices" ] && cp -a "$tr/indices/." "$(workshop_root)/indices/"
  [ -d "$tr/agent-scaffolds" ] && cp -a "$tr/agent-scaffolds/." "$(workshop_root)/agent-scaffolds/"
  [ -d "$tr/scripts" ] && cp -a "$tr/scripts/." "$(workshop_root)/scripts/"
  chmod +x "$(workshop_root)/scripts/"*.sh 2>/dev/null || true
  chmod +x "$(workshop_root)/scripts/"*.py 2>/dev/null || true
}
