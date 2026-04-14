# Skills-first workflow (outside Instruqt)

Use this checklist when you want to **provision and run the A2A lab entirely through [Elastic Agent Skills](https://github.com/elastic/agent-skills)**—no Instruqt, minimal raw `curl`.

## 0. Prerequisite: install Agent Skills

1. Clone or install skills from **`https://github.com/elastic/agent-skills`** (official library, technical preview).
2. Follow the repo **Getting started**: [README — Getting started](https://github.com/elastic/agent-skills#getting-started) (Claude Code plugin, `npx` installer, or clone + installer script).
3. Install at least the **Cloud** and **Elasticsearch auth** skills first; add **Kibana → Agent Builder** when you automate agents.

> Tip from upstream: do not install every skill—only what you need—to avoid context bloat.

## 1. Cloud authentication

| Skill | Use it to… |
| ----- | ---------- |
| [cloud-setup](https://github.com/elastic/agent-skills/blob/main/skills/cloud/setup/SKILL.md) | Set `EC_API_KEY`, `EC_BASE_URL`, `EC_REGION`, validate against the Cloud API. |

Keep secrets in `.env` (this folder’s `env.example`) or your agent’s secret store—**never** paste keys into chat.

## 2. Create two Serverless projects

| Skill | Use it to… |
| ----- | ---------- |
| [cloud-create-project](https://github.com/elastic/agent-skills/blob/main/skills/cloud/create-project/SKILL.md) | Create **Observability** Serverless project (`--type observability`, `--product-tier complete`, `--wait`). |
| [cloud-create-project](https://github.com/elastic/agent-skills/blob/main/skills/cloud/create-project/SKILL.md) | Create **Security** Serverless project (`--type security`, `--product-tier complete`, `--wait`). |

Follow each skill’s confirmation and credential-handling rules (`.elastic-credentials`, scoped keys, etc.).

## 3. Day-2 and credentials (as needed)

| Skill | Use it to… |
| ----- | ---------- |
| [cloud-manage-project](https://github.com/elastic/agent-skills/blob/main/skills/cloud/manage-project/SKILL.md) | List/get projects, `load-credentials`, reset credentials, resume suspended projects. |

## 4. Elasticsearch API keys (lab)

| Skill | Use it to… |
| ----- | ---------- |
| [elasticsearch-authn](https://github.com/elastic/agent-skills/blob/main/skills/elasticsearch/elasticsearch-authn/SKILL.md) | Create **scoped** Elasticsearch API keys for each project (prefer over long-lived admin for workshop traffic). |

Export or save values your workshop shell can read (`O11Y_ES_URL`, `O11Y_API_KEY`, `SECURITY_ES_URL`, `SECURITY_API_KEY`)—same shape as `state/workshop.env` from the bash path.

## 5. Index templates + synthetic bulk data

**Option A — stay in the agent:** use [elasticsearch-file-ingest](https://github.com/elastic/agent-skills/blob/main/skills/elasticsearch/elasticsearch-file-ingest/SKILL.md) or ad-hoc `_bulk` / `_index_template` via [elasticsearch-authn](https://github.com/elastic/agent-skills/blob/main/skills/elasticsearch/elasticsearch-authn/SKILL.md) + [elasticsearch-esql](https://github.com/elastic/agent-skills/blob/main/skills/elasticsearch/elasticsearch-esql/SKILL.md) if you prefer not to run local scripts.

**Option B — one-shot bash (still no Instruqt):** after keys exist, from repo root:

```bash
export ELASTIC_WORKSHOP_ROOT="$(pwd)/elastic-agent-builder-a2a-workshop"
export ELASTIC_WORKSHOP_ENV_FILE="$(pwd)/elastic-agent-builder-a2a-cloud-path/state/workshop.env"
bash "$ELASTIC_WORKSHOP_ROOT/scripts/apply-index-templates.sh"
bash "$ELASTIC_WORKSHOP_ROOT/scripts/load-sample-bulk.sh"
bash "$(pwd)/elastic-agent-builder-a2a-cloud-path/scripts/05-agent-builder-lab-agents.sh"
```

The last line creates starter Agent Builder agents on **both** Kibanas (Security: detection + A2A enrichment; Observability: context) when **Node** and **`agent-builder.js`** are available; otherwise it prints a skip warning. Set **`O11Y_AGENT_ENDPOINT`** in `state/workshop.env` and re-run the script to embed the live Observability URL in enrichment instructions. Same behavior is included in **`scripts/run-all.sh`** after populate.

After projects and keys are ready, use **[`README.md` → Exercise the setup (both paths)](./README.md)** to validate clusters, run optional load simulation, exercise Agent Builder in Kibana, and wire true A2A (HTTP + workflow).

## 6. Agent Builder (Security + Observability)

| Skill | Use it to… |
| ----- | ---------- |
| [kibana-agent-builder](https://github.com/elastic/agent-skills/blob/main/skills/kibana/agent-builder/SKILL.md) | Create/update/test Agent Builder agents and tools in Kibana (see upstream skill for API coverage). |

Align agent behavior with [`../elastic-agent-builder-a2a-workshop/agent-scaffolds/`](../elastic-agent-builder-a2a-workshop/agent-scaffolds/) and [`AGENT_BUILDER.md`](./AGENT_BUILDER.md).

## 7. Optional: security / observability depth

| Area | Skill |
| ---- | ----- |
| Sample security data | [generate-security-sample-data](https://github.com/elastic/agent-skills/blob/main/skills/security/generate-security-sample-data/SKILL.md) |
| Log investigation | [logs-search](https://github.com/elastic/agent-skills/blob/main/skills/observability/logs-search/SKILL.md) |
| Dashboards | [kibana-dashboards](https://github.com/elastic/agent-skills/blob/main/skills/kibana/kibana-dashboards/SKILL.md) |

## When to use bash `scripts/` in this folder

Use **`scripts/run-all.sh`** (or steps `00`–`04`) when you need **headless CI**, **no AI agent**, or a **golden path regression test**. The skills-first flow above is the **recommended** default for sellers/SAs in Cursor (or similar) with Agent Skills installed.
