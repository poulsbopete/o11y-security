#!/usr/bin/env bash
# Shared helpers for Instruqt challenge scripts.

workshop_root() {
  echo "/root/elastic-workshop"
}

# Pass "${BASH_SOURCE[0]}" from the calling setup/check/solve script.
# Instruqt runs challenge lifecycle scripts from a copy under /tmp (BASH_SOURCE is not inside the
# track tree). track_scripts/setup-workstation writes /root/elastic-workshop/.instruqt-track-root;
# otherwise fall back to $PWD, script-relative path, or a shallow find for this track's slug.
track_root_from_challenge_script() {
  local origin="$1"
  local script_dir
  local candidate=""
  local marker
  marker="$(workshop_root)/.instruqt-track-root"
  if [ -n "${ELASTIC_WORKSHOP_TRACK_ROOT:-}" ] && [ -f "${ELASTIC_WORKSHOP_TRACK_ROOT}/track.yml" ]; then
    echo "${ELASTIC_WORKSHOP_TRACK_ROOT}"
    return 0
  fi
  if [ -f "$marker" ]; then
    head -1 "$marker" | tr -d '\r\n'
    return 0
  fi
  if [ -f "$(pwd)/../track.yml" ]; then
    (cd "$(pwd)/.." && pwd)
    return 0
  fi
  script_dir="$(cd "$(dirname "$origin")" && pwd)"
  if [ -f "$script_dir/../track.yml" ]; then
    (cd "$script_dir/.." && pwd)
    return 0
  fi
  if [[ "$origin" == /tmp/* ]] || [[ "$script_dir" == "/tmp" ]]; then
    candidate="$(
      find /opt/instruqt /root /srv /var/tmp -maxdepth 14 -type f -name track.yml 2>/dev/null | while read -r tf; do
        if grep -q 'elastic-a2a-serverless-agent-builder' "$tf" 2>/dev/null; then
          dirname "$tf"
          break
        fi
      done
    )"
    if [ -n "$candidate" ] && [ -f "$candidate/track.yml" ]; then
      echo "$candidate"
      return 0
    fi
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
