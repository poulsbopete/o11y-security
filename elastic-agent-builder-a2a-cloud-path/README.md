# Agent Builder A2A — Cloud bootstrap path (no Instruqt)

This folder is a **second path** to stand up the workshop on real **Elastic Cloud Serverless** projects: one **Observability** and one **Security** project, then mint **Elasticsearch API keys**, apply the workshop **index templates**, and **bulk-load** synthetic data.

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
| Print Kibana URLs + next steps | `scripts/04-print-next-steps.sh` |
| All of the above | `scripts/run-all.sh` |

Prereqs for scripts: `curl`, `jq`, `bash`, and `EC_API_KEY` in `.env` (see `env.example`).

## What stays manual (unless you use a skill)

**Agent Builder** authoring is covered by the **[kibana-agent-builder](https://github.com/elastic/agent-skills/blob/main/skills/kibana/agent-builder/SKILL.md)** skill when you drive everything through Agent Skills. This repo still provides narrative and payload shapes under [`../elastic-agent-builder-a2a-workshop/agent-scaffolds/`](../elastic-agent-builder-a2a-workshop/agent-scaffolds/) and [`AGENT_BUILDER.md`](./AGENT_BUILDER.md).

## Quick start

### Path 1 — Agent Skills (recommended)

1. Install **[elastic/agent-skills](https://github.com/elastic/agent-skills)**.
2. Open **`SKILLS-FIRST-WORKFLOW.md`** and execute each step with your agent (cloud-setup → two × cloud-create-project → elasticsearch-authn → kibana-agent-builder, etc.).

### Path 2 — Bash only

Work from the **repository root** (the folder that **contains** `elastic-agent-builder-a2a-cloud-path/`). Do **not** paste prose or Markdown comments into the shell; only paste the command lines below.

1. Create `.env` once (skip if you already have one):

```bash
cp elastic-agent-builder-a2a-cloud-path/env.example elastic-agent-builder-a2a-cloud-path/.env
```

2. In an editor, open `elastic-agent-builder-a2a-cloud-path/.env` and set **`EC_API_KEY`** to your Elastic Cloud API key from [cloud.elastic.co/account/keys](https://cloud.elastic.co/account/keys). If the key ends with `=`, wrap the whole value in **single quotes**. Remove or replace the empty `EC_API_KEY=` line from the template—do not leave it blank.

3. Run checks and the full pipeline (these work from repo root; no `cd` required):

```bash
bash elastic-agent-builder-a2a-cloud-path/scripts/00-check-prereqs.sh
bash elastic-agent-builder-a2a-cloud-path/scripts/run-all.sh
```

If you prefer to `cd` into the folder first, use **`cd elastic-agent-builder-a2a-cloud-path`** only from the parent directory. If your prompt already shows `elastic-agent-builder-a2a-cloud-path`, you are already there—run `bash scripts/00-check-prereqs.sh` instead of `cd` again.

**Zsh gotchas:** Lines that contain parentheses, e.g. explanatory text with `(use …)`, are **not** comments unless they start with `#`. Zsh may try to glob them and print `no matches found`. Comment lines in docs are for humans only—do not paste them into zsh unless the line begins with `#` at column one.

Outputs (gitignored / sensitive):

- `state/bootstrap.json` — endpoints + **bootstrap credentials** (chmod `600`). Treat like `.elastic-credentials` in the skills: **do not commit**, do not use for routine ES traffic after API keys exist.
- `state/workshop.env` — `O11Y_*` and `SECURITY_*` URLs + **Elasticsearch API keys** for the workshop scripts (chmod `600`).

## Tightening API key privileges

`scripts/api-key-body.json` grants a **lab-wide** role for speed. Narrow `indices.names` and `privileges` before customer-facing demos.

## Troubleshooting

- **`cd: no such file or directory: elastic-agent-builder-a2a-cloud-path`** — You are already inside that directory, or your current directory is not the repo root. Use `pwd` and `ls`, or run the `bash elastic-agent-builder-a2a-cloud-path/scripts/…` paths from the clone root instead of nesting `cd`.
- **`zsh: no matches found: (...)`** — A line with parentheses was executed as a command. In zsh, `(word)` is special; use **only** the bare `bash …` / `cp …` lines from the quick start, or run scripts under **`bash`** so behavior matches the shebang.
- **`Set EC_API_KEY in …/.env`** — The key is missing or empty after loading `.env`. Edit the file with a real key; quote with single quotes if the key ends with `=`.
- **Security create returns 422** — the Cloud API may require extra fields over time. Compare your payload with the latest [Create security project](https://www.elastic.co/docs/api/doc/elastic-cloud-serverless/operation/operation-createsecurityproject) docs and extend `01-provision-serverless.sh`, or rely on **cloud-create-project** from Agent Skills (updated upstream).
- **Elasticsearch `403` on `_security/api_key`** — confirm bootstrap `credentials` exist in `state/bootstrap.json` and that you are calling the **Elasticsearch** endpoint from that file, not Kibana.
