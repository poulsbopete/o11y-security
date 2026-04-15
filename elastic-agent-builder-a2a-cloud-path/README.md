# Agent Builder A2A — Cloud bootstrap path (no Instruqt)

This folder is a **second path** to stand up the workshop on real **Elastic Cloud Serverless** projects: one **Observability** and one **Security** project, then mint **Elasticsearch API keys**, apply the workshop **index templates**, **bulk-load** synthetic data, and (when Node and the **kibana-agent-builder** CLI are available) create **starter Agent Builder agents** on both Kibanas.

Use it when you want a fast loop on real stacks before porting flows into Instruqt.

## What actually bridges Security and Observability (A2A)

The **exercise** is not “two silos that happen to share a repo”—it is **API-first correlation** when each domain keeps its own Serverless project:

- **Bridge:** a **Security** Agent Builder agent (enrichment track) calls the **published Observability** agent over **HTTPS** using **`O11Y_AGENT_ENDPOINT`**, then merges Observability context into Security-side outcomes (e.g. enriched documents, cases, dashboards). That HTTP agent-to-agent hop is the lab’s **A2A**.
- **Supporting pieces:** Kibana **alert → workflow → case** flows and **synth inject** workflows only **refresh workshop data** or **automate triage** inside each project. They do **not** replace the enrichment agent’s call to Observability—see [`AGENT_BUILDER.md`](./AGENT_BUILDER.md) and [`../elastic-agent-builder-a2a-workshop/agent-scaffolds/security-a2a-enrichment-workflow.md`](../elastic-agent-builder-a2a-workshop/agent-scaffolds/security-a2a-enrichment-workflow.md).

## Prerequisite (recommended): Elastic Agent Skills

**Install the official skills library first:** **[elastic/agent-skills](https://github.com/elastic/agent-skills)**.

That repo is the supported way to teach your AI agent (Cursor, Claude Code, Copilot, etc.) to run **cloud-setup**, **cloud-create-project**, **cloud-manage-project**, **elasticsearch-authn**, **kibana-agent-builder**, and related tasks correctly. Follow its [Getting started](https://github.com/elastic/agent-skills#getting-started) and security guidance.

**Primary workflow:** use the skills with your agent to provision both Serverless projects, create scoped API keys, then either:

- continue in skills for ingest / Agent Builder, **or**
- run the small bash helpers in `scripts/` only for **templates + bulk** (see below).

Step-by-step checklist: **[`SKILLS-FIRST-WORKFLOW.md`](./SKILLS-FIRST-WORKFLOW.md)**.

## Bash scripts (optional / CI / headless)

These mirror the same Cloud + Elasticsearch operations when you **do not** have an agent, or you want a deterministic pipeline:

| Step | Script |
| ---- | ------ |
| Validate Cloud API key | `scripts/00-check-prereqs.sh` |
| Create both serverless projects + wait for `initialized` | `scripts/01-provision-serverless.sh` |
| Create scoped **Elasticsearch** API keys (admin bootstrap only) | `scripts/02-create-es-api-keys.sh` |
| Apply templates + load `workshop-synth-*` data | `scripts/03-populate-indices.sh` |
| Create lab Agent Builder agents (both Kibanas: Security detection + A2A enrichment + Observability context) | `scripts/05-agent-builder-lab-agents.sh` |
| Create lab **Kibana Workflows** (alert → **console + Case** in one workflow; optional Case-only; **scheduled** 15m + **manual** synth inject per project) on **both** Kibanas | `scripts/06-kibana-workflows-lab.sh` |
| Create **Elasticsearch query** lab rules (so you get **alerts** from `workshop-synth-*` without new ingest) | `scripts/07-lab-alert-rules.sh` |
| **Optional:** run lab workflows once with a **synthetic** alert payload (`/api/workflows/test`) | `scripts/08-synthetic-workflow-test.sh` |
| Create lab **Dashboards** via **Dashboards API** (`POST`/`PUT` `/api/dashboards` — no `?apiVersion=`) | `scripts/09-lab-dashboards-api.sh` |
| **Optional:** simulate cross-domain **ingest** (fresh `workshop-synth-*` docs → lab rules/workflows) | `scripts/10-lab-simulate-traffic.sh` |
| Print Kibana URLs + next steps | `scripts/04-print-next-steps.sh` |
| All of the above | `scripts/run-all.sh` |

Prereqs for scripts: `curl`, `jq`, `bash`, and `EC_API_KEY` in `.env` (see `env.example`). Step **05** additionally needs **Node.js 18+** and the **`agent-builder.js`** file from the [kibana-agent-builder](https://github.com/elastic/agent-skills/tree/main/skills/kibana/agent-builder) skill (see `env.example` for overrides and skip flags). Step **06** uses the same Kibana bootstrap credentials as **05**; YAML lives under [`kibana-workflows/yaml/`](./kibana-workflows/yaml/). Step **07** **auto-attaches** the lab **alert console** workflow to each `.es-query` rule when **`state/kibana-workflows-lab.json`** exists (after **06**), using the same system connector the UI uses (**`system-connector-.workflows`**). You can still add or change actions in the UI; avoid attaching the separate Case-only workflow on the same rule. Set **`A2A_SKIP_ATTACH_WORKFLOW_RULE_ACTIONS=1`** to skip API attachment. **Scheduled** inject workflows (default **15m**) plus **manual** inject workflows (**Run** in **Workflows**) push `workshop-synth-*` docs—no rule action needed; disable the schedule with **`A2A_SKIP_SCHEDULED_SYNTH_WORKFLOWS=1`**. Lab rules use **`A2A_LAB_RULE_INTERVAL`** (default **5m** in **07**) to reduce Case noise. **ES|QL** or Dev Tools queries **do not** create Kibana alerting alerts — use **07** for rules that fire on existing workshop data, **10** to bulk more workshop traffic (so rules keep matching), or **08** to run workflows once with a **synthetic** alert payload (not the same as a rule-generated alert). Step **09** creates **Analytics dashboards** on each Kibana using **`POST /api/dashboards`** and **`PUT /api/dashboards/{id}`** (do **not** pass `?apiVersion=` on Serverless — Kibana returns 400).

## What stays manual (unless you use a skill)

**`05-agent-builder-lab-agents.sh`** creates **starter** agents and index-search tools on **both** Kibanas from [`agent-instructions/`](./agent-instructions) (Security: detection + enrichment; Observability: context). Tune them with the **[kibana-agent-builder](https://github.com/elastic/agent-skills/blob/main/skills/kibana/agent-builder/SKILL.md)** skill. **Publishing** the Observability agent URL (`O11Y_AGENT_ENDPOINT` in `workshop.env`) and **writing** to `.elastic-agents-security-a2a-enriched` still follow Kibana / workflow product steps—see [`AGENT_BUILDER.md`](./AGENT_BUILDER.md) and [`../elastic-agent-builder-a2a-workshop/agent-scaffolds/`](../elastic-agent-builder-a2a-workshop/agent-scaffolds/).

## Quick start

### Path 1 — Agent Skills (recommended)

1. Install **[elastic/agent-skills](https://github.com/elastic/agent-skills)**.
2. Open **`SKILLS-FIRST-WORKFLOW.md`** and execute each step with your agent (cloud-setup → two × cloud-create-project → elasticsearch-authn → kibana-agent-builder, etc.).

### Path 2 — Bash only

Check where you are with **`pwd`**. The commands differ depending on that directory.

#### A) Repository root (clone contains `elastic-agent-builder-a2a-cloud-path/`)

Do **not** paste prose into the shell; only the commands below.

1. Create `.env` once (skip if you already have one):

```bash
cp elastic-agent-builder-a2a-cloud-path/env.example elastic-agent-builder-a2a-cloud-path/.env
```

2. Edit **`elastic-agent-builder-a2a-cloud-path/.env`**: set **`EC_API_KEY`** from [cloud.elastic.co/account/keys](https://cloud.elastic.co/account/keys). If the key ends with `=`, wrap the value in **single quotes**. Do not leave `EC_API_KEY` blank.

3. Run scripts (paths are relative to repo root):

```bash
bash elastic-agent-builder-a2a-cloud-path/scripts/00-check-prereqs.sh
bash elastic-agent-builder-a2a-cloud-path/scripts/run-all.sh
```

#### B) Already inside `elastic-agent-builder-a2a-cloud-path` (prompt ends with that folder name)

Use **short** paths—there is no `elastic-agent-builder-a2a-cloud-path/` subfolder from here.

```bash
cp env.example .env
```

Edit **`.env`** in this folder with **`EC_API_KEY`** as above, then:

```bash
bash scripts/00-check-prereqs.sh
bash scripts/run-all.sh
```

From the parent folder only, run **`cd elastic-agent-builder-a2a-cloud-path`** once to enter this directory. If your prompt already shows `elastic-agent-builder-a2a-cloud-path`, do not `cd` into that name again.

**Zsh gotchas:** Lines that contain parentheses, e.g. explanatory text with `(use …)`, are **not** comments unless they start with `#`. Zsh may try to glob them and print `no matches found`. Comment lines in docs are for humans only—do not paste them into zsh unless the line begins with `#` at column one.

Outputs (gitignored / sensitive):

- `state/bootstrap.json` — endpoints + **bootstrap credentials** (chmod `600`). Treat like `.elastic-credentials` in the skills: **do not commit**, do not use for routine ES traffic after API keys exist.
- `state/workshop.env` — `O11Y_*` and `SECURITY_*` URLs + **Elasticsearch API keys** for the workshop scripts (chmod `600`).
- `state/agent-builder-lab.json` — IDs of starter agents/tools from **`05-agent-builder-lab-agents.sh`** (chmod `600`, present only when step 05 succeeds).

## Exercise the setup (both paths)

Use these steps after projects exist, credentials are in **`state/workshop.env`**, and (for Path 2) **`run-all.sh`** has finished—or after you complete the equivalent steps via Agent Skills (**Path 1**). Repo root paths below assume you cloned **[o11y-security](https://github.com/poulsbopete/o11y-security)**. To **present** the same setup to others (slides, Dev Tools, load script, Agent Builder, A2A caveat), see **[Demo the setup](#demo-the-setup)** below.

### Path 1 — Agent Skills (outside Instruqt)

1. **Confirm Elasticsearch** — load API keys from `workshop.env` (create the file via **elasticsearch-authn** / **cloud-manage-project** if you did not use bash `02`/`03`):

   ```bash
   set -a; source elastic-agent-builder-a2a-cloud-path/state/workshop.env; set +a
   curl -sS -H "Authorization: ApiKey ${SECURITY_API_KEY}" "${SECURITY_ES_URL}/_cluster/health" | jq .
   curl -sS -H "Authorization: ApiKey ${O11Y_API_KEY}" "${O11Y_ES_URL}/_cluster/health" | jq .
   ```

2. **Templates + sample data** — if you skipped bash `03`, run **Option B** in [`SKILLS-FIRST-WORKFLOW.md`](./SKILLS-FIRST-WORKFLOW.md) (`apply-index-templates.sh` + `load-sample-bulk.sh`) so `workshop-synth-*` indices exist.

3. **Agent Builder** — use **[kibana-agent-builder](https://github.com/elastic/agent-skills/tree/main/skills/kibana/agent-builder)** to mirror [`../elastic-agent-builder-a2a-workshop/agent-scaffolds/`](../elastic-agent-builder-a2a-workshop/agent-scaffolds/) on each Kibana, **or** run **`scripts/05-agent-builder-lab-agents.sh`** once Node and `agent-builder.js` are available.

4. **Kibana** — open both Kibana URLs (from **`scripts/04-print-next-steps.sh`** or `state/bootstrap.json`). In **Agent Builder → Agents**, confirm lab agents (e.g. **A2A Lab …**) or your skill-created equivalents.

5. **Chat smoke tests** — **Observability**: open **A2A Lab Observability Context** (or your context agent) and ask for `prod-db-01` over the last minute using metrics/traces. **Security**: open **A2A Lab Security Detection** / **A2A Lab Security A2A Enrichment** and ask about auth failures on `prod-db-01`.

6. **Stress both clusters** (optional, same as Path 2 step 6):

   ```bash
   export ELASTIC_WORKSHOP_ROOT="$(pwd)/elastic-agent-builder-a2a-workshop"
   export ELASTIC_WORKSHOP_ENV_FILE="$(pwd)/elastic-agent-builder-a2a-cloud-path/state/workshop.env"
   SIMULATE_ROUNDS=20 SIMULATE_BURST_SIZE=15 SIMULATE_SLEEP_SEC=1 \
     bash elastic-agent-builder-a2a-workshop/scripts/simulate-cross-domain-load.sh
   ```

   Tune with `SIMULATE_*` env vars in that script; `SIMULATE_DRY_RUN=1` skips `_bulk`.

7. **True A2A (HTTP)** — publish the Observability agent URL, set **`O11Y_AGENT_ENDPOINT`** in `state/workshop.env`, re-run **`05`** (or **update-agent** via the skill), then add the **HTTP** step in a **Security** workflow per [`../elastic-agent-builder-a2a-workshop/04-connect-agents-a2a/assignment.md`](../elastic-agent-builder-a2a-workshop/04-connect-agents-a2a/assignment.md). Details: [`AGENT_BUILDER.md`](./AGENT_BUILDER.md).

### Path 2 — Bash `run-all.sh`

1. **Print URLs and reminders**

   ```bash
   bash elastic-agent-builder-a2a-cloud-path/scripts/04-print-next-steps.sh
   ```

2. **Cluster health** (same as Path 1 step 1).

3. **Agent Builder** — if **`05`** was skipped, install **[kibana-agent-builder](https://github.com/elastic/agent-skills/tree/main/skills/kibana/agent-builder)** and run **`bash elastic-agent-builder-a2a-cloud-path/scripts/05-agent-builder-lab-agents.sh`**.

4. **Kibana smoke** — same as Path 1 steps 4–5.

5. **Stress** — run the **`simulate-cross-domain-load.sh`** block from Path 1 step 6.

6. **Validate in Kibana Dev Tools (Console)** — **not** in your terminal: open **Security** Kibana → **Dev Tools** (or **Management → Dev Tools**), then paste the two-line request below. Pasting `GET …` + `{ … }` into **zsh** will error (`parse error near '}'`) because `{` is shell syntax.

   ```text
   GET workshop-synth-endpoint-alerts/_search
   { "size": 5, "sort": [{ "@timestamp": "desc" }], "query": { "term": { "host.name": "prod-db-01" } } }
   ```

   Repeat on **Observability** Kibana for `workshop-synth-metrics` / `workshop-synth-traces` (indices may differ if templates were rejected on Serverless).

7. **True A2A** — same as Path 1 step 7.

**Workshop-only exercises** (Instruqt track, challenge order, `Check` scripts): see **[`../elastic-agent-builder-a2a-workshop/README.md`](../elastic-agent-builder-a2a-workshop/README.md)**.

## Demo the setup

Walk a buyer, SA, or exec through what this repo already stands up (two Serverless projects, **`workshop-synth-*`** data, optional **A2A Lab** agents, load generator). For **Instruqt-only** delivery, use **[`../elastic-agent-builder-a2a-workshop/README.md` § Demo](../elastic-agent-builder-a2a-workshop/README.md#demo-the-setup)**.

### Prep (~2 minutes)

- Two browser tabs: **Security** Kibana and **Observability** Kibana — URLs from **`bash elastic-agent-builder-a2a-cloud-path/scripts/04-print-next-steps.sh`** or **`state/bootstrap.json`**.
- Optional: **[GitHub Pages slides](https://poulsbopete.github.io/o11y-security/)** (value prop) and **[AE prompt library](https://poulsbopete.github.io/o11y-security/prompts/)** (positioning / persona copy).
- Confirm **`state/workshop.env`** exists for **`curl`** and **`simulate-cross-domain-load.sh`**.

### Suggested arc (~8–12 minutes)

1. **Framing** — Slides or one sentence: projects are split **on purpose**; A2A means **API-first enrichment**, not copying all analytics into Security.
2. **Evidence in Elasticsearch** — **Security** Kibana → **Dev Tools** (Console only): run the **`GET workshop-synth-endpoint-alerts/_search`** example from **Exercise the setup → Path 2 → step 6** above. **Observability** Kibana → same pattern for **`workshop-synth-metrics`** / **`workshop-synth-traces`**.
3. **Correlated spike** — from repo root, generate parallel Security + Observability load, then refresh Dev Tools / **Discover**:

   ```bash
   export ELASTIC_WORKSHOP_ROOT="$(pwd)/elastic-agent-builder-a2a-workshop"
   export ELASTIC_WORKSHOP_ENV_FILE="$(pwd)/elastic-agent-builder-a2a-cloud-path/state/workshop.env"
   SIMULATE_ROUNDS=15 SIMULATE_BURST_SIZE=12 SIMULATE_SLEEP_SEC=0 \
     bash elastic-agent-builder-a2a-workshop/scripts/simulate-cross-domain-load.sh
   ```

4. **Agent Builder** — **Agents**: contrast built-in **read-only** agents with **A2A Lab …** agents. **Chat**: Observability context → ask for **`prod-db-01`** over the last minute; Security enrichment → ask to correlate auth failures with ops context.
5. **“Real” A2A HTTP** — Be explicit: live **POST** from Security to Observability needs **`O11Y_AGENT_ENDPOINT`** plus a **workflow** step (see **[`AGENT_BUILDER.md`](./AGENT_BUILDER.md)** and **[`../elastic-agent-builder-a2a-workshop/04-connect-agents-a2a/assignment.md`](../elastic-agent-builder-a2a-workshop/04-connect-agents-a2a/assignment.md)**). Optional: set the URL in **`workshop.env`** and re-run **`05`** so instructions stay current.

### Exec / sponsor cut (~3 minutes)

Slides → one **Dev Tools** query on Security → one line on **same host** spiking in Security + Observability (load script or narrative) → **Agents** list → “HTTP + workflow is the next commitment step.”

## Tightening API key privileges

`scripts/api-key-body.json` grants a **lab-wide** role for speed. Narrow `indices.names` and `privileges` before customer-facing demos.

## Troubleshooting

- **`cp: elastic-agent-builder-a2a-cloud-path/env.example: No such file or directory`** — Your shell is **already inside** `elastic-agent-builder-a2a-cloud-path`. Use **`cp env.example .env`** (section **B** above), not the long paths from section **A**.
- **`cd: no such file or directory: elastic-agent-builder-a2a-cloud-path`** — You are already inside that directory, or your current directory is not the repo root. Use `pwd` and `ls`, or run the `bash elastic-agent-builder-a2a-cloud-path/scripts/…` paths from the clone root instead of nesting `cd`.
- **`zsh: no matches found: (...)`** — A line with parentheses was executed as a command. In zsh, `(word)` is special; use **only** the bare `bash …` / `cp …` lines from the quick start, or run scripts under **`bash`** so behavior matches the shebang.
- **`Set EC_API_KEY in …/.env`** — The key is missing or empty after loading `.env`. Edit the file with a real key; quote with single quotes if the key ends with `=`.
- **Security create returns 422** — the Cloud API may require extra fields over time. Compare your payload with the latest [Create security project](https://www.elastic.co/docs/api/doc/elastic-cloud-serverless/operation/operation-createsecurityproject) docs and extend `01-provision-serverless.sh`, or rely on **cloud-create-project** from Agent Skills (updated upstream).
- **Elasticsearch `403` on `_security/api_key`** — confirm bootstrap `credentials` exist in `state/bootstrap.json` and that you are calling the **Elasticsearch** endpoint from that file, not Kibana.
- **`401` with `oauth2 token: invalid token` on `_index_template` or `_bulk`** — workshop scripts must send native ES API keys as **`Authorization: ApiKey …`**, not `Bearer`. If you hit this on an older clone, pull the latest workshop `scripts/apply-index-templates.sh` and `scripts/load-sample-bulk.sh`, then re-run **`bash scripts/03-populate-indices.sh`** (your existing `state/workshop.env` is fine).
- **`zsh: parse error near '}'`** after pasting **`GET index/_search`** and a JSON body — that snippet is for **Kibana Dev Tools**, not the shell. Open Kibana → **Dev Tools** and paste there; or wrap a one-line search in **`curl`** to Elasticsearch with **`Authorization: ApiKey …`** (see Path 1 step 1).
