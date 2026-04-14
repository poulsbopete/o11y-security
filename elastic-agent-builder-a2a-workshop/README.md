# Agent Builder A2A — Workshop (Instruqt track source)

This directory is the **source tree** for the **Instruqt** workshop *Agent Builder A2A: Serverless Observability + Security Communication*. It contains `track.yml`, challenges **`01-`…`06-`**, index templates, sample data, scripts, and **agent scaffolds** used in assignments.

**Cloud / Agent Skills path (no Instruqt):** use the sibling folder on GitHub — **[`elastic-agent-builder-a2a-cloud-path`](https://github.com/poulsbopete/o11y-security/tree/main/elastic-agent-builder-a2a-cloud-path)** — and its **[`README.md`](https://github.com/poulsbopete/o11y-security/blob/main/elastic-agent-builder-a2a-cloud-path/README.md)** (includes **Exercise the setup** for both **Path 1 — Skills** and **Path 2 — Bash**).

---

## Exercise the setup — Instruqt path

1. **Install the Instruqt CLI** and authenticate per [Instruqt documentation](https://docs.instruqt.com/).
2. **Push the track** from this directory (or your fork): `instruqt track push` (or your org’s equivalent) so learners get the latest challenges.
3. **Run the track** in a sandbox or workshop event. Learners use the **Terminal** tab and **Assignment** tab per challenge.
4. **Follow challenges in order** — each folder has `assignment.md`, `setup-workstation`, `check-workstation`, and usually `solve-workstation`:

   | # | Challenge | What you exercise |
   | - | --------- | ------------------- |
   | 01 | [`01-lay-the-foundation`](./01-lay-the-foundation/assignment.md) | Two clusters, `.env`, cluster health, index templates + bulk sample data |
   | 02 | [`02-build-security-agent`](./02-build-security-agent/assignment.md) | Security Agent Builder detection agent + `workshop-synth-endpoint-alerts` |
   | 03 | [`03-build-observability-agent`](./03-build-observability-agent/assignment.md) | Observability context agent + metrics/traces |
   | 04 | [`04-connect-agents-a2a`](./04-connect-agents-a2a/assignment.md) | **A2A**: HTTP to Observability, merge, enrich index |
   | 05 | [`05-unified-dashboard`](./05-unified-dashboard/assignment.md) | ES|QL / dashboard correlation (optional depth) |
   | 06 | [`06-response-agent-optional`](./06-response-agent-optional/assignment.md) | Optional response automation |

5. **Click Check** after each challenge when the assignment says to — `check-workstation` validates the lab state.
6. **Stuck?** Use **Show solution** only if the event policy allows it; compare with `solve-workstation` scripts.

**Scaffolds** (copy/paste prompts and shapes for Agent Builder): [`agent-scaffolds/`](./agent-scaffolds/).

---

## Exercise the setup — Your own Elastic (no Instruqt)

Use this when you already have **two** Elasticsearch endpoints + API keys (e.g. from **[cloud-path](https://github.com/poulsbopete/o11y-security/tree/main/elastic-agent-builder-a2a-cloud-path)** `state/workshop.env`).

1. **Export paths** (from repo root):

   ```bash
   export ELASTIC_WORKSHOP_ROOT="$(pwd)/elastic-agent-builder-a2a-workshop"
   export ELASTIC_WORKSHOP_ENV_FILE="/path/to/workshop.env"
   ```

   `workshop.env` must define `SECURITY_ES_URL`, `SECURITY_API_KEY`, `O11Y_ES_URL`, `O11Y_API_KEY` (same shape as cloud-path output).

2. **Load templates and sample NDJSON**

   ```bash
   bash "$ELASTIC_WORKSHOP_ROOT/scripts/apply-index-templates.sh"
   bash "$ELASTIC_WORKSHOP_ROOT/scripts/load-sample-bulk.sh"
   ```

3. **Optional stress** — correlated Security + Observability bursts:

   ```bash
   SIMULATE_ROUNDS=20 SIMULATE_BURST_SIZE=15 SIMULATE_SLEEP_SEC=1 \
     bash "$ELASTIC_WORKSHOP_ROOT/scripts/simulate-cross-domain-load.sh"
   ```

4. **Agent Builder in Kibana** — follow [`agent-scaffolds/`](./agent-scaffolds/) on each Serverless Kibana, or run cloud-path **`05-agent-builder-lab-agents.sh`** if you use that repo layout and have Node + **kibana-agent-builder** installed.

5. **A2A HTTP** — same as Instruqt challenge **04**: publish Observability URL, set `O11Y_AGENT_ENDPOINT`, workflow HTTP step on Security — see **[`../elastic-agent-builder-a2a-cloud-path/AGENT_BUILDER.md`](../elastic-agent-builder-a2a-cloud-path/AGENT_BUILDER.md)**.

---

## Scripts (reference)

| Script | Purpose |
| ------ | ------- |
| [`scripts/apply-index-templates.sh`](./scripts/apply-index-templates.sh) | PUT index templates on Security cluster |
| [`scripts/load-sample-bulk.sh`](./scripts/load-sample-bulk.sh) | `_bulk` sample data into `workshop-synth-*` |
| [`scripts/simulate-cross-domain-load.sh`](./scripts/simulate-cross-domain-load.sh) | Parallel load: auth failures (Security) + metrics/traces (Observability) |
| [`scripts/workshop-common.sh`](./scripts/workshop-common.sh) | Helpers for Instruqt lifecycle scripts |
