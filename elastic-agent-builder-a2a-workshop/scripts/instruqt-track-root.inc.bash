# shellcheck shell=bash
# Resolve the on-VM path to this track (directory containing track.yml).
# Instruqt copies challenge lifecycle scripts to /tmp; never use dirname "$0"/.. from there.
elastic_workshop_resolve_track_root() {
  local origin="${1:-}"
  local slug="elastic-a2a-serverless-agent-builder"
  local tr="" tf="" script_dir="" marker="/root/elastic-workshop/.instruqt-track-root"

  if [ -n "${ELASTIC_WORKSHOP_TRACK_ROOT:-}" ] && [ -f "${ELASTIC_WORKSHOP_TRACK_ROOT}/track.yml" ]; then
    echo "${ELASTIC_WORKSHOP_TRACK_ROOT}"
    return 0
  fi

  if [ -s "$marker" ]; then
    tr="$(head -1 "$marker" | tr -d '\r\n')"
    if [ -n "$tr" ] && [ -f "$tr/track.yml" ]; then
      echo "$tr"
      return 0
    fi
  fi

  if [ -n "$origin" ] && [ -e "$origin" ]; then
    script_dir="$(cd "$(dirname "$origin")" && pwd)"
    if [ -f "$script_dir/../track.yml" ] && grep -q "$slug" "$script_dir/../track.yml" 2>/dev/null; then
      (cd "$script_dir/.." && pwd)
      return 0
    fi
  fi

  local search_roots=(
    /opt/instruqt
    /opt/elastic
    /opt
    /var/lib/instruqt
    /var/lib
    /srv
    /usr/local
    /home
    /root
    /mnt
    /var/tmp
    /tmp
    /usr/share
    /snap
  )
  local base=""
  for base in "${search_roots[@]}"; do
    [ -d "$base" ] || continue
    while IFS= read -r tf; do
      [ -f "$tf" ] || continue
      grep -q "$slug" "$tf" 2>/dev/null || continue
      dirname "$tf"
      return 0
    done < <(find "$base" -maxdepth 24 -type f -name track.yml 2>/dev/null)
  done

  while IFS= read -r tf; do
    [ -f "$tf" ] || continue
    grep -q "$slug" "$tf" 2>/dev/null || continue
    dirname "$tf"
    return 0
  done < <(find / -maxdepth 10 -type f -name track.yml 2>/dev/null)

  return 1
}
