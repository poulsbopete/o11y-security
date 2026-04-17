#!/usr/bin/env bash
# Shared helpers for Instruqt challenge scripts.

_wc_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$_wc_dir/instruqt-track-root.inc.bash" ]; then
  # shellcheck disable=SC1091
  source "$_wc_dir/instruqt-track-root.inc.bash"
fi

workshop_root() {
  echo "/root/elastic-workshop"
}

# Pass "${BASH_SOURCE[0]}" from the calling setup/check/solve script.
# Instruqt runs challenge lifecycle scripts from a copy under /tmp (BASH_SOURCE is not inside the
# track tree). Prefer marker + shared resolver in instruqt-track-root.inc.bash — never fall back
# to dirname /tmp/.. → /.
track_root_from_challenge_script() {
  local origin="$1"
  if declare -F elastic_workshop_resolve_track_root >/dev/null 2>&1; then
    elastic_workshop_resolve_track_root "$origin" || true
    return 0
  fi
  echo ""
  return 0
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
  [ -d "$tr/assets" ] && cp -a "$tr/assets/." "$(workshop_root)/assets/"
  [ -d "$tr/sample-data" ] && cp -a "$tr/sample-data/." "$(workshop_root)/sample-data/"
  [ -d "$tr/indices" ] && cp -a "$tr/indices/." "$(workshop_root)/indices/"
  [ -d "$tr/agent-scaffolds" ] && cp -a "$tr/agent-scaffolds/." "$(workshop_root)/agent-scaffolds/"
  [ -d "$tr/scripts" ] && cp -a "$tr/scripts/." "$(workshop_root)/scripts/"
  chmod +x "$(workshop_root)/scripts/"*.sh 2>/dev/null || true
  chmod +x "$(workshop_root)/scripts/"*.py 2>/dev/null || true
}
