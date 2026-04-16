# Agent Builder A2A — Workshop (Instruqt track source)

This directory is the **source tree** for the **Instruqt** workshop *Agent Builder A2A: Serverless Observability + Security Communication*. It contains `track.yml` (**track slug:** `elastic-a2a-serverless-agent-builder`), challenges **`01-`…`06-`**, index templates, sample data, scripts, and **agent scaffolds** used in assignments.

**Lab UI:** each challenge exposes **Serverless Observability** and **Serverless Security** [service tabs](https://docs.instruqt.com/tracks/challenges/challenge-tabs) on the single **workstation** container. Nginx listens on **8080** / **8081** and reverse-proxies to the Kibana URLs in `.env`; after editing `.env`, run `sudo bash /root/elastic-workshop/scripts/render-kibana-proxy.sh` (challenge **01** explains the flow). Ports **8080** and **8081** are declared in `config.yml` for Instruqt’s web proxy. Service tabs use the same shape as **[elastic-autonomous-observability](https://play.instruqt.com/manage/elastic/tracks/elastic-autonomous-observability)**: a **Dashboards** `path` plus **`custom_request_headers`** and **`custom_response_headers`** (each with `Content-Security-Policy` and the multiline `''` quoting Instruqt expects—**not** `custom_headers`, which the UI does not surface). **`scripts/render-kibana-proxy.sh`** mirrors that CSP on nginx (and strips upstream `Content-Security-Policy` / `X-Frame-Options`) so the lab stays usable if tab metadata is edited only in the UI.

**Team secrets:** sandbox bindings to team-level secrets must appear under `secrets:` in [`config.yml`](./config.yml) (names only; values stay in **Settings → Secrets** on Instruqt). This repo lists **`LLM_PROXY_PROD`** and **`ESS_CLOUD_API_KEY`** so a plain `instruqt track push` does not drop them—see [Add secrets to tracks](https://docs.instruqt.com/sandboxes/runtime/secrets). Lifecycle scripts receive each as an environment variable of the same name.

**Cloud / Agent Skills path (no Instruqt):** use the sibling folder on GitHub — **[`elastic-agent-builder-a2a-cloud-path`](https://github.com/poulsbopete/o11y-security/tree/main/elastic-agent-builder-a2a-cloud-path)** — and its **[`README.md`](https://github.com/poulsbopete/o11y-security/blob/main/elastic-agent-builder-a2a-cloud-path/README.md)** (includes **Exercise the setup** for both **Path 1 — Skills** and **Path 2 — Bash**).

---

## Exercise the setup — Instruqt path

To **demo or facilitate** the track (screen layout, challenge highlights, optional load script), see **[Demo the setup](#demo-the-setup)** below.

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

**Scaffolds** (copy/paste prompts and shapes for Agent Builder): [`agent-scaffolds/`](./agent-scaffolds/) — includes **[`alert-to-case-with-dual-project-audit.md`](./agent-scaffolds/alert-to-case-with-dual-project-audit.md)** for alert-driven workflows, dual-project audit text, and Security Cases.

---

## Exercise the setup — Your own Elastic (no Instruqt)

For a **buyer-facing walkthrough** after these steps, use **[Demo the setup](#demo-the-setup)** (and the linked **[cloud-path demo](../elastic-agent-builder-a2a-cloud-path/README.md#demo-the-setup)** for the full script).

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

## Demo the setup

Use this section to **facilitate or record** a walkthrough. If you provisioned stacks with **[cloud-path](https://github.com/poulsbopete/o11y-security/tree/main/elastic-agent-builder-a2a-cloud-path)**, follow the fuller checklist there: **[`../elastic-agent-builder-a2a-cloud-path/README.md` § Demo the setup](../elastic-agent-builder-a2a-cloud-path/README.md#demo-the-setup)** (slides, Dev Tools, load script, Agent Builder chat, A2A boundary).

### Instruqt (facilitator-led)

1. **Before the session** — push the track; confirm sandboxes resolve **two** Kibana URLs and credentials from challenge **01**.
2. **Screen share** — **Assignment** (left) + **Serverless Observability** / **Serverless Security** / **Terminal**; keep [`agent-scaffolds/`](./agent-scaffolds/) open in your browser for copy/paste.
3. **Challenge 01** — “Two projects on purpose”; show cluster health and loaded **`workshop-synth-*`** data.
4. **Challenges 02–03** — Security detection + Observability context agents (Agent Builder UI).
5. **Challenge 04** — **Demo peak**: HTTP to Observability, merged enriched story; passing **Check** is your “A2A works” moment.
6. **Challenge 05** (optional) — ES|QL / dashboard: “one narrative for execs.”
7. **Optional live pressure** — if policy allows Elasticsearch egress from the sandbox, run **[`scripts/simulate-cross-domain-load.sh`](./scripts/simulate-cross-domain-load.sh)** with `ELASTIC_WORKSHOP_*` set (same env shape as cloud-path `workshop.env`), then re-show **Discover** or Dev Tools.

### Your own Elastic (no Instruqt)

Use the **same narrative** as **[cloud-path README → Demo the setup](../elastic-agent-builder-a2a-cloud-path/README.md#demo-the-setup)** after **`apply-index-templates`**, **`load-sample-bulk`**, and (optional) **`05-agent-builder-lab-agents.sh`**.

---

## Scripts (reference)

| Script | Purpose |
| ------ | ------- |
| [`scripts/apply-index-templates.sh`](./scripts/apply-index-templates.sh) | PUT index templates on Security cluster |
| [`scripts/load-sample-bulk.sh`](./scripts/load-sample-bulk.sh) | `_bulk` sample data into `workshop-synth-*` |
| [`scripts/simulate-cross-domain-load.sh`](./scripts/simulate-cross-domain-load.sh) | Parallel load: auth failures (Security) + metrics/traces (Observability) |
| [`scripts/workshop-common.sh`](./scripts/workshop-common.sh) | Helpers for Instruqt lifecycle scripts |
