#!/usr/bin/env bash
# Index lab-app source into workshop-synth-sourcecode on Observability (and mirror to Security).
# This is the Instruqt-reliable "Sourcerer-like" path: grep/search the code in Elasticsearch
# without installing https://github.com/elastic/sourcerer (optional on the cloud path via script 11).
set -euo pipefail

ROOT="${ELASTIC_WORKSHOP_ROOT:-/root/elastic-workshop}"
ENV_FILE="${ELASTIC_WORKSHOP_ENV_FILE:-$ROOT/.env}"
if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE — set ELASTIC_WORKSHOP_ENV_FILE." >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

for v in O11Y_ES_URL O11Y_API_KEY; do
  if [ -z "${!v:-}" ]; then
    echo "Missing ${v} in ${ENV_FILE}" >&2
    exit 1
  fi
done

LAB="${ROOT}/lab-app"
if [ ! -d "$LAB" ]; then
  echo "Missing ${LAB}" >&2
  exit 1
fi

TPL="$ROOT/indices/sourcecode-template.json"
if [ ! -f "$TPL" ]; then
  echo "Missing ${TPL}" >&2
  exit 1
fi

put_template() {
  local url="$1"
  local key="$2"
  curl -sS -X PUT "${url}/_index_template/workshop-sourcecode" \
    -H "Authorization: ApiKey ${key}" \
    -H "Content-Type: application/json" \
    --data-binary "@${TPL}" >/dev/null
}

put_template "$O11Y_ES_URL" "$O11Y_API_KEY"
if [ -n "${SECURITY_ES_URL:-}" ] && [ -n "${SECURITY_API_KEY:-}" ] && [ "${WORKSHOP_SKIP_MIRROR_O11Y_INDICES_TO_SECURITY:-0}" != "1" ]; then
  put_template "$SECURITY_ES_URL" "$SECURITY_API_KEY"
fi

delete_idx() {
  local url="$1"
  local key="$2"
  curl -sS -o /dev/null -X DELETE "${url}/workshop-synth-sourcecode" \
    -H "Authorization: ApiKey ${key}" || true
}

delete_idx "$O11Y_ES_URL" "$O11Y_API_KEY"
if [ -n "${SECURITY_ES_URL:-}" ] && [ -n "${SECURITY_API_KEY:-}" ] && [ "${WORKSHOP_SKIP_MIRROR_O11Y_INDICES_TO_SECURITY:-0}" != "1" ]; then
  delete_idx "$SECURITY_ES_URL" "$SECURITY_API_KEY"
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ndjson="$(mktemp "${TMPDIR:-/tmp}/workshop-src.XXXXXX.ndjson")"
trap 'rm -f "$ndjson"' EXIT

python3 - "$LAB" "$ts" "$ndjson" <<'PY'
import json, pathlib, re, sys

lab = pathlib.Path(sys.argv[1])
ts = sys.argv[2]
out = pathlib.Path(sys.argv[3])
skip = {"static"}
ext_ok = {".py", ".md", ".html", ".json", ".yml", ".yaml", ".txt"}

def tags_for(text):
    return sorted(set(re.findall(r"LAB_VULN:([a-z0-9_]+)", text)))

with out.open("w", encoding="utf-8") as fh:
    for path in sorted(lab.rglob("*")):
        if not path.is_file():
            continue
        if any(p in skip for p in path.relative_to(lab).parts[:-1]):
            continue
        if path.suffix.lower() not in ext_ok:
            continue
        rel = str(path.relative_to(lab.parent))
        text = path.read_text(encoding="utf-8", errors="replace")
        if len(text) > 200_000:
            text = text[:200_000] + "\n…truncated…\n"
        doc = {
            "@timestamp": ts,
            "file": {
                "path": rel,
                "extension": path.suffix.lstrip("."),
                "content": text,
            },
            "git": {
                "host": "github",
                "org": "poulsbopete",
                "repo": "o11y-security",
                "ref": "main",
            },
            "lab": {
                "vuln_tags": tags_for(text),
                "service": "claims-portal",
                "host": "prod-db-01",
            },
            "workshop": {"demo_stream": "code", "narrative": "dual_mission_lab"},
        }
        fh.write(json.dumps({"index": {"_index": "workshop-synth-sourcecode"}}) + "\n")
        fh.write(json.dumps(doc) + "\n")
PY

bulk() {
  local url="$1"
  local key="$2"
  local resp
  resp="$(curl -sS -X POST "${url}/_bulk" \
    -H "Authorization: ApiKey ${key}" \
    -H "Content-Type: application/x-ndjson" \
    --data-binary "@${ndjson}")"
  if ! echo "$resp" | jq -e '.errors == false' >/dev/null 2>&1; then
    echo "_bulk errors posting sourcecode to ${url}:" >&2
    echo "$resp" | jq . >&2 2>/dev/null || echo "$resp" >&2
    return 1
  fi
}

bulk "$O11Y_ES_URL" "$O11Y_API_KEY"
if [ -n "${SECURITY_ES_URL:-}" ] && [ -n "${SECURITY_API_KEY:-}" ] && [ "${WORKSHOP_SKIP_MIRROR_O11Y_INDICES_TO_SECURITY:-0}" != "1" ]; then
  bulk "$SECURITY_ES_URL" "$SECURITY_API_KEY"
fi

count="$(python3 -c "print(sum(1 for _ in open('${ndjson}') ) // 2)")"
echo "Indexed ${count} lab-app source file(s) into workshop-synth-sourcecode (Observability${SECURITY_ES_URL:+ + Security mirror})."
echo "ES|QL: FROM workshop-synth-sourcecode | WHERE file.content LIKE \"*LAB_VULN*\" | KEEP file.path, lab.vuln_tags"
