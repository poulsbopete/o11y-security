# Dual-mission logs demo (Web / Database / OS)

Facilitator notes for the **same telemetry, two missions** story (Observability vs Security), aligned with workshop bulk data and the GitHub Pages deck slide **“Do you see a vase or a face?”**

This narrative is intentionally **plain**—three ubiquitous log planes, two readouts—so it lands for **Serverless** and **self-managed** customers alike.

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

1. **Observability Kibana → Discover** — Data view on `workshop-synth-metrics` and `workshop-synth-traces`. Filter `host.name: prod-db-01` and `workshop.demo_stream: web` (or `os`). Narrate **SLO pain**: high CPU, slow or failing HTTP transactions.
2. **Security Kibana → Discover** — `workshop-synth-endpoint-alerts`, same host, `workshop.demo_stream: database`. Narrate **risk**: repeated auth failures, suspicious source IPs.
3. **Tie together** — Run **`simulate-cross-domain-load.sh`** (or cloud-path **`scripts/10-lab-simulate-traffic.sh`**) so all three streams move in the same window; refresh Discover in both projects.
4. **Optional** — Open **Agent Builder** on each side and ask for “last 15 minutes on `prod-db-01`” with an explicit **Ops** vs **Sec** prompt.

## ES|QL snippets (Dev Tools)

Observability cluster:

```esql
FROM workshop-synth-traces
| WHERE host.name == "prod-db-01" AND workshop.demo_stream == "web"
| SORT @timestamp DESC
| LIMIT 20
```

```esql
FROM workshop-synth-metrics
| WHERE host.name == "prod-db-01" AND workshop.demo_stream == "os"
| STATS max_cpu = MAX(system.cpu.total.norm.pct) BY @timestamp
| SORT @timestamp DESC
| LIMIT 20
```

Security cluster:

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
