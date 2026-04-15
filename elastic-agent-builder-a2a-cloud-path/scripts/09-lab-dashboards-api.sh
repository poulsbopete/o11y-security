#!/usr/bin/env bash
# Create or update lab dashboards via **POST/PUT /api/dashboards** (Dashboards as code API).
# Do **not** use ?apiVersion= — on Serverless, that query string is rejected.
#
# Security / Observability: markdown (ES|QL + **navigation** + optional **HTML diagram** Security/O11y→MCP)
# plus **Lens-style metric** tiles (`vis` + `data_view_spec`) — counts, unique values,
# and max/avg on numeric workshop fields.
#
# Requires: curl, jq, bash, state/bootstrap.json.
# Writes: state/kibana-dashboards-lab.json (dashboard ids for updates).
# Skip: A2A_SKIP_LAB_DASHBOARDS=1
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

CURL="${CURL:-/usr/bin/curl}"
BOOT="$ROOT/state/bootstrap.json"
STATE="$ROOT/state/kibana-dashboards-lab.json"

load_dotenv "$ROOT/.env"

if [ "${A2A_SKIP_LAB_DASHBOARDS:-0}" = "1" ]; then
  echo "Skipping lab dashboards API (A2A_SKIP_LAB_DASHBOARDS=1)."
  exit 0
fi

if [ ! -f "$BOOT" ]; then
  echo "Missing ${BOOT} — run provisioning first." >&2
  exit 1
fi

require_cmds "$CURL" jq

umask 077
mkdir -p "$ROOT/state"
if [ ! -f "$STATE" ]; then
  echo '{"security":null,"observability":null}' >"$STATE"
  chmod 600 "$STATE"
fi

# After `01-provision-serverless.sh`, project ids change but `state/kibana-dashboards-lab.json` may still
# hold old dashboard UUIDs → PUT 404/400 then POST creates a **second** row with the same title. Clear ids
# when bootstrap project fingerprints change.
reset_dashboard_state_if_projects_changed() {
  local boot="$1" state="$2"
  local cur_s cur_o prev_s prev_o
  cur_s="$(jq -r '.security.id // empty' "$boot")"
  cur_o="$(jq -r '.observability.id // empty' "$boot")"
  prev_s="$(jq -r '._bootstrap_security_project // empty' "$state")"
  prev_o="$(jq -r '._bootstrap_observability_project // empty' "$state")"
  [ -n "$cur_s" ] && [ -n "$cur_o" ] || return 0
  if [ -n "$prev_s" ] && [ -n "$prev_o" ] && { [ "$prev_s" != "$cur_s" ] || [ "$prev_o" != "$cur_o" ]; }; then
    echo "  Bootstrap project id(s) changed — clearing stale dashboard ids in $(basename "$state")."
    merged="$(jq --arg cs "$cur_s" --arg co "$cur_o" \
      '.security = null | .observability = null | ._bootstrap_security_project = $cs | ._bootstrap_observability_project = $co' "$state")"
    printf '%s\n' "$merged" >"$state"
    chmod 600 "$state"
  else
    merged="$(jq --arg cs "$cur_s" --arg co "$cur_o" \
      '. + {_bootstrap_security_project: $cs, _bootstrap_observability_project: $co}' "$state")"
    printf '%s\n' "$merged" >"$state"
    chmod 600 "$state"
  fi
}

# List all dashboard ids whose title equals $want (newline-separated).
dashboard_ids_for_title() {
  local base="$1" user="$2" pass="$3" want="$4"
  local tmp
  tmp="$(mktemp)"
  if ! "$CURL" -sS -o "$tmp" -u "${user}:${pass}" -H "kbn-xsrf: true" "${base%/}/api/dashboards?per_page=200"; then
    rm -f "$tmp"
    return 1
  fi
  jq -r --arg t "$want" '.dashboards[]? | select(.data.title == $t) | .id' "$tmp"
  rm -f "$tmp"
}

# Keep at most one dashboard for this title. Prefer $keep_id when it appears in the list.
dedupe_dashboards_for_title() {
  local base="$1" user="$2" pass="$3" title="$4" keep_id="${5:-}"
  local tmp ids keeper id
  tmp="$(mktemp)"
  if ! "$CURL" -sS -o "$tmp" -u "${user}:${pass}" -H "kbn-xsrf: true" "${base%/}/api/dashboards?per_page=200"; then
    rm -f "$tmp"
    return 1
  fi
  ids=()
  while IFS= read -r line; do
    [ -n "$line" ] && ids+=("$line")
  done < <(jq -r --arg t "$title" '.dashboards[]? | select(.data.title == $t) | .id' "$tmp")
  rm -f "$tmp"
  [ "${#ids[@]}" -le 1 ] && return 0
  keeper=""
  if [ -n "$keep_id" ]; then
    for id in "${ids[@]}"; do
      if [ "$id" = "$keep_id" ]; then keeper="$id"; break; fi
    done
  fi
  [ -z "$keeper" ] && keeper="${ids[0]}"
  for id in "${ids[@]}"; do
    if [ "$id" != "$keeper" ]; then
      echo "  Dedupe: DELETE duplicate dashboard id=${id} (same title as lab dashboard)"
      "$CURL" -sS -o /dev/null -u "${user}:${pass}" -H "kbn-xsrf: true" -X DELETE "${base%/}/api/dashboards/${id}" || true
    fi
  done
}

# Kibana expects stable per-panel `id` on PUT; omitting them can yield blank panels. Merge ids from GET.
merge_dashboard_body_with_saved_panel_ids() {
  local saved_get_json="$1" incoming_json="$2" out_json="$3"
  # `incoming_json` must be a file containing a single JSON object (title, time_range, panels).
  jq -n --slurpfile s "$saved_get_json" --slurpfile n "$incoming_json" '
    ($s[0].data.panels // []) as $sp |
    ($n[0]) as $in |
    ($in.panels) as $np |
    $in
    | .panels = [
        range(0; ($np | length)) as $i
        | $np[$i]
        * (if (($sp | length) > $i) and ($sp[$i].id != null) and ($sp[$i].id != "") then {id: $sp[$i].id} else {} end)
      ]
  ' >"$out_json"
}

dash_upsert() {
  local role="$1" base="$2" user="$3" pass="$4" title="$5" body_json="$6"
  local id code key tmp_body tmp_out merged original_body
  key="$([ "$role" = security ] && echo security || echo observability)"
  original_body="$body_json"

  dedupe_dashboards_for_title "$base" "$user" "$pass" "$title" "$(jq -r --arg k "$key" '.[$k] // empty' "$STATE")"

  id="$(jq -r --arg k "$key" '.[$k] // empty' "$STATE")"
  if [ -n "$id" ] && [ "$id" != "null" ]; then
    code="$("$CURL" -sS -o /tmp/dash-get.json -w "%{http_code}" -u "${user}:${pass}" \
      -H "kbn-xsrf: true" "${base%/}/api/dashboards/${id}")" || true
    if [ "$code" != "200" ]; then
      echo "  WARN: saved id ${id} not found (HTTP ${code}); clearing ${key} in state and re-resolving by title."
      merged="$(jq --arg k "$key" '.[$k] = null' "$STATE")"
      printf '%s\n' "$merged" >"$STATE"
      chmod 600 "$STATE"
      id=""
    fi
  fi

  if [ -z "$id" ] || [ "$id" = "null" ]; then
    id="$(dashboard_ids_for_title "$base" "$user" "$pass" "$title" | head -n 1)"
    if [ -n "$id" ]; then
      merged="$(jq --arg k "$key" --arg id "$id" '.[$k] = $id' "$STATE")"
      printf '%s\n' "$merged" >"$STATE"
      chmod 600 "$STATE"
      echo "  Found existing ${role} dashboard id=${id} (title match)"
    fi
  fi

  tmp_body="$(mktemp)"
  printf '%s' "$original_body" >"$tmp_body"

  if [ -n "$id" ] && [ "$id" != "null" ]; then
    body_json="$original_body"
    if "$CURL" -sS -o /tmp/dash-get.json -u "${user}:${pass}" -H "kbn-xsrf: true" "${base%/}/api/dashboards/${id}"; then
      tmp_out="$(mktemp)"
      if merge_dashboard_body_with_saved_panel_ids /tmp/dash-get.json "$tmp_body" "$tmp_out" 2>/dev/null; then
        body_json="$(cat "$tmp_out")"
      fi
      rm -f "$tmp_out"
    fi
    code="$("$CURL" -sS -o /tmp/dash-resp.json -w "%{http_code}" -u "${user}:${pass}" \
      -H "kbn-xsrf: true" -H "Content-Type: application/json" \
      -X PUT "${base%/}/api/dashboards/${id}" -d "$body_json")" || true
    if [ "$code" = "200" ]; then
      echo "  PUT ${role} dashboard (${title})"
      rm -f "$tmp_body"
      dedupe_dashboards_for_title "$base" "$user" "$pass" "$title" "$id"
      return 0
    fi
    echo "  WARN: PUT ${id} HTTP ${code}; will POST new…" >&2
    /usr/bin/head -c 600 /tmp/dash-resp.json >&2 || true
    echo >&2
  fi

  rm -f "$tmp_body"
  body_json="$original_body"
  id="$("$CURL" -sS -u "${user}:${pass}" -H "kbn-xsrf: true" -H "Content-Type: application/json" \
    -X POST "${base%/}/api/dashboards" -d "$body_json" | jq -r '.id // empty')"
  if [ -z "$id" ]; then
    echo "POST dashboard failed for ${role}" >&2
    return 1
  fi
  merged="$(jq --arg k "$key" --arg id "$id" '.[$k] = $id' "$STATE")"
  printf '%s\n' "$merged" >"$STATE"
  chmod 600 "$STATE"
  echo "  POST ${role} dashboard id=${id} (${title})"
  dedupe_dashboards_for_title "$base" "$user" "$pass" "$title" "$id"
}

sec_kb="$(jq -r '.security.endpoints.kibana // empty' "$BOOT")"
sec_user="$(jq -r '.security.credentials.username // empty' "$BOOT")"
sec_pass="$(jq -r '.security.credentials.password // empty' "$BOOT")"
o11y_kb="$(jq -r '.observability.endpoints.kibana // empty' "$BOOT")"
o11y_user="$(jq -r '.observability.credentials.username // empty' "$BOOT")"
o11y_pass="$(jq -r '.observability.credentials.password // empty' "$BOOT")"

if [ -z "$sec_kb" ] || [ -z "$sec_user" ] || [ -z "$sec_pass" ]; then
  echo "Missing Security Kibana URL or credentials in bootstrap.json." >&2
  exit 1
fi
if [ -z "$o11y_kb" ] || [ -z "$o11y_user" ] || [ -z "$o11y_pass" ]; then
  echo "Missing Observability Kibana URL or credentials in bootstrap.json." >&2
  exit 1
fi

reset_dashboard_state_if_projects_changed "$BOOT" "$STATE"

SEC_TITLE="A2A Lab — Security workshop"
O11Y_TITLE="A2A Lab — Observability workshop"

read -r -d '' SEC_HERO <<'EOF' || true
## Security workshop — live board

> **What this is:** Synthetic **authentication failures** plus optional **A2A-enriched** agent audit rows. The KPI strip uses **distinct source IPs** and **distinct log lines** (cardinality on keyword fields that behave well in Security), plus auth volume and enriched-doc count.

**Focus host for copy-paste queries:** `prod-db-01`
EOF

read -r -d '' SEC_MD <<'EOF' || true
### Workshop data & ES|QL

**Indices:** `workshop-synth-endpoint-alerts`, `.elastic-agents-security-a2a-enriched`

```
FROM workshop-synth-endpoint-alerts
| WHERE host.name == "prod-db-01"
| STATS c = COUNT(*) BY @timestamp
| SORT @timestamp DESC
| LIMIT 20
```

```
FROM .elastic-agents-security-a2a-enriched
| STATS c = COUNT(*), avg_ms = AVG(a2a_response_time_ms) BY severity
| SORT c DESC
```
EOF

read -r -d '' SEC_NAV <<'EOF' || true
### Alerts, cases & workflows (this dashboard does **not** list alerts)

**Kibana alerting** is separate from Analytics dashboards. After **`scripts/07-lab-alert-rules.sh`**, open:

- [Elastic Security → Cases](/app/security/cases)
- [Stack Management → Rules](/app/management/insightsAndAlerting/rules) (filter tag **a2a-lab** — lab rules are **Elasticsearch query** rules)
- [Elastic Security → Alerts](/app/security/alerts) (detection alerts; lab workshop rules use consumer **alerts** — also check **Stack Management → Rules** for **Recent alerts** on each rule)

Lab rules default to **5m** (set **`A2A_LAB_RULE_INTERVAL`** in **07**). **07** auto-attaches **A2A Lab — alert audit (console)** when **`state/kibana-workflows-lab.json`** exists.

> **If metric tiles still error:** hard-refresh the page (**reload** bypassing cache). This dashboard uses **cardinality on `source.ip.keyword` and `message.keyword`** (some Security/Lens builds mishandle `host.name` / `user.name` with ad-hoc data views). Canonical id: **`a2a-lab-security-workshop`** in `state/kibana-dashboards-lab.json`.
EOF

read -r -d '' O11Y_HERO <<'EOF' || true
## Observability workshop — mini SRE board

> **Why you are here:** This space is intentionally **loud in words, quiet in charts** — workshop metrics and traces are synthetic, but the **alerts → workflows → cases** path is real. Skim the hero, steal the ES|QL, then let the KPI tiles tell you if volume and peaks look sane for the time range.

### Indices at a glance

| Workshop index | Role |
| --- | --- |
| `workshop-synth-metrics` | CPU & memory time series per host |
| `workshop-synth-traces` | APM-style spans, latency, `event.outcome` |

**Default story host:** `prod-db-01` — tune the `WHERE` clauses if your load script used another hostname.
EOF

read -r -d '' O11Y_MD <<'EOF' || true
### ES|QL — copy, paste, tweak

**Metrics — rolling CPU by bucket**

```
FROM workshop-synth-metrics
| WHERE host.name == "prod-db-01"
| STATS max_cpu = MAX(system.cpu.total.norm.pct) BY @timestamp
| SORT @timestamp DESC
| LIMIT 20
```

**Traces — failed transactions only**

```
FROM workshop-synth-traces
| WHERE host.name == "prod-db-01" AND event.outcome == "failure"
| STATS fails = COUNT(*)
| LIMIT 10
```
EOF

read -r -d '' O11Y_NAV <<'EOF' || true
### Ops links — alerts, cases, rules

**TL;DR:** Nothing on this Analytics dashboard subscribes to alerting state. You will not “see alerts” here until you wire a dedicated panel or jump to the Observability apps below.

| Need | Go here |
| --- | --- |
| Firing / acknowledged alerts | [Observability → Alerts](/app/observability/alerts) |
| Incident threads | [Observability → Cases](/app/observability/cases) |
| Lab `.es-query` rules (tag **a2a-lab**) | [Stack Management → Rules](/app/management/insightsAndAlerting/rules) |

**Workflows:** after **`06`**, attach **A2A Lab — O11y alert log** on each lab rule — it **logs and opens an Observability case** in one workflow (ids in `state/kibana-workflows-lab.json`). Do not attach the separate case-only workflow on the same rule.
EOF

# HTML diagram (markdown panel): Security + Observability → MCP. Kibana markdown allows common inline styles.
read -r -d '' MCP_DIAGRAM <<'EOF' || true
### Security + Observability → MCP

<p style="color:#555;margin:0 0 12px;">Concept diagram — both domains feed a shared <strong>Model Context Protocol (MCP)</strong> layer so agents and tools can use Security and Observability context together.</p>

<div style="display:flex;align-items:center;gap:18px;flex-wrap:wrap;justify-content:center;font-family:system-ui,-apple-system,sans-serif;max-width:960px;margin:0 auto;">
  <div style="display:flex;flex-direction:column;gap:12px;flex:1;min-width:220px;">
    <div style="background:#fff8e1;border:1px solid #e6d59e;border-radius:8px;padding:12px;">
      <div style="font-weight:600;text-align:center;margin-bottom:8px;">Security data</div>
      <div style="background:#e8e0ff;border-radius:6px;padding:10px;text-align:center;">Endpoint, EDR, firewalls</div>
    </div>
    <div style="background:#fff8e1;border:1px solid #e6d59e;border-radius:8px;padding:12px;">
      <div style="font-weight:600;text-align:center;margin-bottom:8px;">Observability data</div>
      <div style="background:#e8e0ff;border-radius:6px;padding:10px;text-align:center;">APM, infra, app logs</div>
    </div>
  </div>
  <div style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;font-size:26px;color:#333;line-height:1;" aria-hidden="true"><span>↘</span><span>↗</span></div>
  <div style="background:#e8e0ff;border:1px solid #c4b5fd;border-radius:8px;padding:22px 26px;font-weight:600;text-align:center;min-width:100px;">MCP</div>
</div>

<p style="color:#777;font-size:12px;margin:12px 0 0;">To use your own graphic: add an <strong>Image</strong> panel in the dashboard editor, or replace this markdown with an <code>&lt;img src="…"&gt;</code> pointing to a hosted PNG/SVG (allowlist may apply).</p>
EOF

SEC_BODY="$(jq -n \
  --arg title "$SEC_TITLE" \
  --arg hero "$SEC_HERO" \
  --arg diagram "$MCP_DIAGRAM" \
  --arg md "$SEC_MD" \
  --arg nav "$SEC_NAV" \
  '{
    title: $title,
    time_range: {from: "now-7d", to: "now"},
    panels: [
      {type: "markdown", grid: {x: 0, y: 0, w: 48, h: 5}, config: {content: $hero}},
      {type: "markdown", grid: {x: 0, y: 5, w: 48, h: 10}, config: {content: $diagram}},
      {type: "markdown", grid: {x: 0, y: 15, w: 48, h: 7}, config: {content: $md}},
      {type: "markdown", grid: {x: 0, y: 22, w: 48, h: 7}, config: {content: $nav}},
      {
        type: "vis",
        grid: {x: 0, y: 29, w: 12, h: 9},
        config: {
          type: "metric",
          data_source: {type: "data_view_spec", index_pattern: "workshop-synth-endpoint-alerts", time_field: "@timestamp"},
          metrics: [{type: "primary", operation: "unique_count", field: "source.ip.keyword", label: "Distinct source IPs"}]
        }
      },
      {
        type: "vis",
        grid: {x: 12, y: 29, w: 12, h: 9},
        config: {
          type: "metric",
          data_source: {type: "data_view_spec", index_pattern: "workshop-synth-endpoint-alerts", time_field: "@timestamp"},
          metrics: [{type: "primary", operation: "unique_count", field: "message.keyword", label: "Distinct messages"}]
        }
      },
      {
        type: "vis",
        grid: {x: 24, y: 29, w: 12, h: 9},
        config: {
          type: "metric",
          data_source: {type: "data_view_spec", index_pattern: "workshop-synth-endpoint-alerts", time_field: "@timestamp"},
          metrics: [{type: "primary", operation: "count", label: "Auth failure events"}]
        }
      },
      {
        type: "vis",
        grid: {x: 36, y: 29, w: 12, h: 9},
        config: {
          type: "metric",
          data_source: {type: "data_view_spec", index_pattern: ".elastic-agents-security-a2a-enriched", time_field: "@timestamp"},
          metrics: [{type: "primary", operation: "count", label: "Enriched A2A docs"}]
        }
      }
    ]
  }')"

O11Y_BODY="$(jq -n \
  --arg title "$O11Y_TITLE" \
  --arg hero "$O11Y_HERO" \
  --arg diagram "$MCP_DIAGRAM" \
  --arg md "$O11Y_MD" \
  --arg nav "$O11Y_NAV" \
  '{
    title: $title,
    time_range: {from: "now-7d", to: "now"},
    panels: [
      {type: "markdown", grid: {x: 0, y: 0, w: 48, h: 10}, config: {content: $hero}},
      {type: "markdown", grid: {x: 0, y: 10, w: 48, h: 10}, config: {content: $diagram}},
      {type: "markdown", grid: {x: 0, y: 20, w: 48, h: 9}, config: {content: $md}},
      {type: "markdown", grid: {x: 0, y: 29, w: 48, h: 8}, config: {content: $nav}},
      {
        type: "vis",
        grid: {x: 0, y: 37, w: 12, h: 9},
        config: {
          type: "metric",
          data_source: {type: "data_view_spec", index_pattern: "workshop-synth-metrics", time_field: "@timestamp"},
          metrics: [{type: "primary", operation: "count", label: "Metric docs"}]
        }
      },
      {
        type: "vis",
        grid: {x: 12, y: 37, w: 12, h: 9},
        config: {
          type: "metric",
          data_source: {type: "data_view_spec", index_pattern: "workshop-synth-traces", time_field: "@timestamp"},
          metrics: [{type: "primary", operation: "count", label: "Trace docs"}]
        }
      },
      {
        type: "vis",
        grid: {x: 24, y: 37, w: 12, h: 9},
        config: {
          type: "metric",
          data_source: {type: "data_view_spec", index_pattern: "workshop-synth-metrics", time_field: "@timestamp"},
          metrics: [{type: "primary", operation: "max", field: "system.cpu.total.norm.pct", label: "Peak CPU (norm)"}]
        }
      },
      {
        type: "vis",
        grid: {x: 36, y: 37, w: 12, h: 9},
        config: {
          type: "metric",
          data_source: {type: "data_view_spec", index_pattern: "workshop-synth-traces", time_field: "@timestamp"},
          metrics: [{type: "primary", operation: "max", field: "transaction.duration.us", label: "Slowest txn (µs)"}]
        }
      },
      {
        type: "vis",
        grid: {x: 0, y: 46, w: 24, h: 9},
        config: {
          type: "metric",
          data_source: {type: "data_view_spec", index_pattern: "workshop-synth-metrics", time_field: "@timestamp"},
          metrics: [{type: "primary", operation: "average", field: "system.cpu.total.norm.pct", label: "Avg CPU"}]
        }
      },
      {
        type: "vis",
        grid: {x: 24, y: 46, w: 24, h: 9},
        config: {
          type: "metric",
          data_source: {type: "data_view_spec", index_pattern: "workshop-synth-metrics", time_field: "@timestamp"},
          metrics: [{type: "primary", operation: "average", field: "system.memory.actual.used.pct", label: "Avg memory %"}]
        }
      }
    ]
  }')"

echo "== Dashboards API: Security Kibana =="
dash_upsert security "$sec_kb" "$sec_user" "$sec_pass" "$SEC_TITLE" "$SEC_BODY"

echo "== Dashboards API: Observability Kibana =="
dash_upsert observability "$o11y_kb" "$o11y_user" "$o11y_pass" "$O11Y_TITLE" "$O11Y_BODY"

echo "Wrote ${STATE}"
echo "Security dashboard id: $(jq -r '.security // "?"' "$STATE")  Observability id: $(jq -r '.observability // "?"' "$STATE")"
echo "Open **Analytics → Dashboards** on each Kibana and search for titles starting with **A2A Lab**."
echo "API: POST /api/dashboards (create), PUT /api/dashboards/{id} (update). Do not append ?apiVersion= on Serverless."
