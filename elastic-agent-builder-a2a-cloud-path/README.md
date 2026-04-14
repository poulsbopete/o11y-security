# Agent Builder A2A — Cloud bootstrap path (no Instruqt)

This folder is a **second path** to stand up the workshop on real **Elastic Cloud Serverless** projects: one **Observability** and one **Security** project, then mint **Elasticsearch API keys**, apply the workshop **index templates**, **bulk-load** synthetic data, and (when Node and the **kibana-agent-builder** CLI are available) create **starter Agent Builder agents** on both Kibanas.

Use it when you want a fast loop on real stacks before porting flows into Instruqt.

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
| Create lab Agent Builder agents (Security + Observability) | `scripts/05-agent-builder-lab-agents.sh` |
| Print Kibana URLs + next steps | `scripts/04-print-next-steps.sh` |
| All of the above | `scripts/run-all.sh` |

Prereqs for scripts: `curl`, `jq`, `bash`, and `EC_API_KEY` in `.env` (see `env.example`). Step **05** additionally needs **Node.js 18+** and the **`agent-builder.js`** file from the [kibana-agent-builder](https://github.com/elastic/agent-skills/tree/main/skills/kibana/agent-builder) skill (see `env.example` for overrides and skip flags).

## What stays manual (unless you use a skill)

**`05-agent-builder-lab-agents.sh`** creates **starter** agents and index-search tools from [`agent-instructions/`](./agent-instructions); tune or extend them with the **[kibana-agent-builder](https://github.com/elastic/agent-skills/blob/main/skills/kibana/agent-builder/SKILL.md)** skill. **A2A enrichment** (HTTP call to Observability, write to `.elastic-agents-security-a2a-enriched`) and **public Observability URLs** still require Kibana/product steps—see [`AGENT_BUILDER.md`](./AGENT_BUILDER.md) and [`../elastic-agent-builder-a2a-workshop/agent-scaffolds/`](../elastic-agent-builder-a2a-workshop/agent-scaffolds/).

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
