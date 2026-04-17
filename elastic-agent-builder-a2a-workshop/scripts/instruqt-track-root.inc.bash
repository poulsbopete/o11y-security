# shellcheck shell=bash
# Resolve the on-VM path to this track (directory containing track.yml).
# Instruqt copies challenge lifecycle scripts to /tmp; never use dirname "$0"/.. from there.
#
# On some sandboxes (especially es3-api) the bundle lives under /terraform/<track-id>/…
# which a shallow find / misses.

elastic_workshop_track_yml_matches() {
  local tf="$1"
  [ -f "$tf" ] || return 1
  # Slug line (authoritative) or stable track id from track.yml (Instruqt copies id verbatim).
  if grep -q 'elastic-a2a-serverless-agent-builder' "$tf" 2>/dev/null; then
    return 0
  fi
  if grep -qE '^id:[[:space:]]*zq70yyfn826u' "$tf" 2>/dev/null; then
    return 0
  fi
  return 1
}

elastic_workshop_resolve_track_root() {
  local origin="${1:-}"
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
    if [ -f "$script_dir/../track.yml" ] && elastic_workshop_track_yml_matches "$script_dir/../track.yml"; then
      (cd "$script_dir/.." && pwd)
      return 0
    fi
  fi

  # Typical Instruqt + Terraform layout (see sandbox logs: /terraform/<track-id>/…).
  if [ -d /terraform ]; then
    while IFS= read -r tf; do
      elastic_workshop_track_yml_matches "$tf" || continue
      dirname "$tf"
      return 0
    done < <(find /terraform -maxdepth 40 -type f -name track.yml 2>/dev/null)
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
    /workspace
    /challenges
  )
  local base=""
  for base in "${search_roots[@]}"; do
    [ -d "$base" ] || continue
    while IFS= read -r tf; do
      elastic_workshop_track_yml_matches "$tf" || continue
      dirname "$tf"
      return 0
    done < <(find "$base" -maxdepth 28 -type f -name track.yml 2>/dev/null)
  done

  # Last resort: bounded full scan (deeper than before; avoids missing /terraform subtrees).
  while IFS= read -r tf; do
    elastic_workshop_track_yml_matches "$tf" || continue
    dirname "$tf"
    return 0
  done < <(find / -maxdepth 22 -type f -name track.yml 2>/dev/null)

  return 1
}
