# Dual-mission logs demo (Web / Database / OS)

Facilitator notes for the **same telemetry, two missions** story (Observability vs Security), aligned with workshop bulk data and the GitHub Pages deck slide **“Do you see a vase or a face?”**

This narrative is intentionally **plain**—three ubiquitous log planes, two readouts—so it lands for **Serverless** and **self-managed** customers alike.

## Observability & Security Cases (alert workflows)

**New titles only appear on newly opened cases.** Older rows (e.g. “Resource saturation”, “Error budget burn”) were created by the previous Liquid templates. After **`06-kibana-workflows-lab.sh`** refreshes **A2A Lab — O11y alert log** / **O11y alert to Case** / **alert audit (console)** / **alert to Security Case**, the next time a lab rule fires you should see:

- **Traces** rule → suffix **Web / API — …** in the case title.
- **Metrics** rule → **OS / host — …**
- **Endpoint** rule (Security) → **Database / auth — …** or **Database — …**

Existing cases are not renamed in place.

## Analytics dashboards

After **`scripts/09-lab-dashboards-api.sh`**, open **Analytics → Dashboards** in each Kibana and search **`A2A Lab`**. You get:

- **A2A Lab — Security workshop** / **A2A Lab — Observability workshop** — original MCP + KPI strip.
- **A2A Lab — Dual mission (Security Kibana)** / **A2A Lab — Dual mission (Observability Kibana)** — copy-paste ES|QL for **`workshop.demo_stream`** plus metric tiles (Security board counts traces + metrics mirrored onto Security ES).

Dashboard ids are stored in **`state/kibana-dashboards-lab.json`** (gitignored).

## Field tag

Synthetic documents include:

```text
workshop.demo_stream = web | database | os
```

| `workshop.demo_stream` | Workshop index | What it represents in the lab |
| ---------------------- | ---------------- | ----------------------------- |
| `web` | `workshop-synth-traces` | HTTP-style transactions (latency, status codes). |
| `database` | `workshop-synth-endpoint-alerts` | Security-style events on the **database host** (`prod-db-01`): failed authentication, lateral-movement precursors. |
| `os` | `workshop-synth-metrics` | Host saturation (CPU, memory, disk). |

**Talk track:** “We did not stand up three different products—we labeled the same correlated spike so **Ops** and **Sec** can ask different questions of the **same** `host.name`.”

## Suggested arc (3–4 minutes, inside the longer lab)

1. **Analytics → Dashboards** — Open **A2A Lab — Dual mission (… Kibana)** on each project (after **`09-lab-dashboards-api.sh`**) for ES|QL copy blocks and KPI tiles.
2. **Observability Kibana → Discover** — Data view on `workshop-synth-metrics` and `workshop-synth-traces`. Filter `host.name: prod-db-01` and `workshop.demo_stream: web` (or `os`). Narrate **SLO pain**: high CPU, slow or failing HTTP transactions.
3. **Security Kibana → Discover** — `workshop-synth-endpoint-alerts`, same host, `workshop.demo_stream: database`. Narrate **risk**: repeated auth failures, suspicious source IPs.
4. **Tie together** — Run **`simulate-cross-domain-load.sh`** (or cloud-path **`scripts/10-lab-simulate-traffic.sh`**) so all three streams move in the same window; refresh Discover in both projects.
5. **Optional** — Open **Agent Builder** on each side and ask for “last 15 minutes on `prod-db-01`” with an explicit **Ops** vs **Sec** prompt.

## ES|QL snippets (Dev Tools)

**Where to run them:** After **`load-sample-bulk.sh`** (or cloud-path **`03-populate-indices.sh`**), `workshop-synth-metrics` and `workshop-synth-traces` exist on **both** Elasticsearch endpoints (Observability is canonical; Security gets a **mirror copy** so **Security Kibana → ES|QL** is not empty). `workshop-synth-endpoint-alerts` lives on **Security** only.

If you see **`Unknown index [workshop-synth-traces]`** in Security Kibana, re-run **`03-populate-indices.sh`** or **`load-sample-bulk.sh`** on a checkout **after** the mirror change, or set `WORKSHOP_SKIP_MIRROR_O11Y_INDICES_TO_SECURITY=1` only when you intentionally want traces/metrics **only** on Observability.

**Traces (web):**

```esql
FROM workshop-synth-traces
| WHERE host.name == "prod-db-01" AND workshop.demo_stream == "web"
| SORT @timestamp DESC
| LIMIT 20
```

**Metrics (os):**

```esql
FROM workshop-synth-metrics
| WHERE host.name == "prod-db-01" AND workshop.demo_stream == "os"
| STATS max_cpu = MAX(system.cpu.total.norm.pct) BY @timestamp
| SORT @timestamp DESC
| LIMIT 20
```

**Endpoint-style auth failures (database host story) — Security index:**

```esql
FROM workshop-synth-endpoint-alerts
| WHERE host.name == "prod-db-01" AND workshop.demo_stream == "database"
| SORT @timestamp DESC
| LIMIT 20
```

## Exec one-liner

> “You already pay to store web, database, and OS telemetry for reliability. Security is mostly a **different filter** on the same streams—plus automation and cases when you wire Elastic end-to-end.”

## Related repo paths

- Slide deck: [`../docs/index.html`](../docs/index.html)
- Load generator: [`../elastic-agent-builder-a2a-workshop/scripts/simulate-cross-domain-load.sh`](../elastic-agent-builder-a2a-workshop/scripts/simulate-cross-domain-load.sh)
- Full facilitator checklist: [`README.md`](./README.md) → **Demo the setup**
