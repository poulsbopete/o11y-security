# shellcheck shell=bash
# Resolve the on-VM path to this track (directory containing track.yml).
# Instruqt copies challenge lifecycle scripts to /tmp; never use dirname "$0"/.. from there.
#
# Some sandboxes omit /terraform on the learner host, bury track.yml very deep, or ship only
# a subset of files — locating scripts/workshop-common.sh via a unique sentinel is the most
# reliable bootstrap signal for this track.

ELASTIC_INSTRUQT_SENTINEL='ELASTIC_INSTRUQT_TRACK_SLUG:elastic-a2a-serverless-agent-builder'

elastic_workshop_track_yml_matches() {
  local tf="$1"
  [ -f "$tf" ] || return 1
  if grep -q 'elastic-a2a-serverless-agent-builder' "$tf" 2>/dev/null; then
    return 0
  fi
  if grep -qE '^id:[[:space:]]*"?zq70yyfn826u"?' "$tf" 2>/dev/null; then
    return 0
  fi
  return 1
}

elastic_workshop_resolve_via_workshop_common() {
  local wf="" tr="" base=""
  local roots=(
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
    /media
    /var/tmp
    /tmp
    /usr/share
    /snap
    /workspace
    /challenges
    /instruqt
    /run
  )
  for base in "${roots[@]}"; do
    [ -d "$base" ] || continue
    while IFS= read -r wf; do
      [ -f "$wf" ] || continue
      grep -qF "$ELASTIC_INSTRUQT_SENTINEL" "$wf" 2>/dev/null || continue
      tr="$(cd "$(dirname "$wf")/.." && pwd)"
      if [ -f "$tr/scripts/workshop-common.sh" ]; then
        echo "$tr"
        return 0
      fi
    done < <(find "$base" -maxdepth 48 -type f -name workshop-common.sh 2>/dev/null)
  done
  while IFS= read -r wf; do
    [ -f "$wf" ] || continue
    grep -qF "$ELASTIC_INSTRUQT_SENTINEL" "$wf" 2>/dev/null || continue
    tr="$(cd "$(dirname "$wf")/.." && pwd)"
    if [ -f "$tr/scripts/workshop-common.sh" ]; then
      echo "$tr"
      return 0
    fi
  done < <(find / -maxdepth 36 -type f -name workshop-common.sh 2>/dev/null)
  return 1
}

elastic_workshop_find_track_yml() {
  find "$@" \( -type f \( -name track.yml -o -name track.yaml \) \) 2>/dev/null
}

elastic_workshop_resolve_track_root() {
  local origin="${1:-}"
  local tr="" tf="" script_dir="" marker="/root/elastic-workshop/.instruqt-track-root"

  if [ -n "${ELASTIC_WORKSHOP_TRACK_ROOT:-}" ] && [ -f "${ELASTIC_WORKSHOP_TRACK_ROOT}/scripts/workshop-common.sh" ]; then
    echo "${ELASTIC_WORKSHOP_TRACK_ROOT}"
    return 0
  fi

  if [ -s "$marker" ]; then
    tr="$(head -1 "$marker" | tr -d '\r\n')"
    if [ -n "$tr" ] && [ -f "$tr/scripts/workshop-common.sh" ]; then
      echo "$tr"
      return 0
    fi
  fi

  if [ -n "$origin" ] && [ -e "$origin" ]; then
    script_dir="$(cd "$(dirname "$origin")" && pwd)"
    if [ -f "$script_dir/../track.yml" ] && elastic_workshop_track_yml_matches "$script_dir/../track.yml"; then
      cand="$(cd "$script_dir/.." && pwd)"
      if [ -f "$cand/scripts/workshop-common.sh" ]; then
        echo "$cand"
        return 0
      fi
    fi
    if [ -f "$script_dir/../track.yaml" ] && elastic_workshop_track_yml_matches "$script_dir/../track.yaml"; then
      cand="$(cd "$script_dir/.." && pwd)"
      if [ -f "$cand/scripts/workshop-common.sh" ]; then
        echo "$cand"
        return 0
      fi
    fi
  fi

  if [ -d /terraform ]; then
    while IFS= read -r tf; do
      elastic_workshop_track_yml_matches "$tf" || continue
      cand="$(dirname "$tf")"
      [ -f "$cand/scripts/workshop-common.sh" ] || continue
      echo "$cand"
      return 0
    done < <(elastic_workshop_find_track_yml /terraform -maxdepth 45)
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
    /media
    /var/tmp
    /tmp
    /usr/share
    /snap
    /workspace
    /challenges
    /instruqt
  )
  local base=""
  for base in "${search_roots[@]}"; do
    [ -d "$base" ] || continue
    while IFS= read -r tf; do
      elastic_workshop_track_yml_matches "$tf" || continue
      cand="$(dirname "$tf")"
      [ -f "$cand/scripts/workshop-common.sh" ] || continue
      echo "$cand"
      return 0
    done < <(elastic_workshop_find_track_yml "$base" -maxdepth 32)
  done

  while IFS= read -r tf; do
    elastic_workshop_track_yml_matches "$tf" || continue
    cand="$(dirname "$tf")"
    [ -f "$cand/scripts/workshop-common.sh" ] || continue
    echo "$cand"
    return 0
  done < <(elastic_workshop_find_track_yml / -maxdepth 30)

  if tr="$(elastic_workshop_resolve_via_workshop_common)"; then
    echo "$tr"
    return 0
  fi
  return 1
}
