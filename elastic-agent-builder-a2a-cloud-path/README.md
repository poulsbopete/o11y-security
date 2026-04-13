# Agent Builder A2A — Cloud bootstrap path (no Instruqt)

This folder is a **second path** to stand up the workshop on real **Elastic Cloud Serverless** projects: one **Observability** and one **Security** project, then mint **Elasticsearch API keys**, apply the workshop **index templates**, and **bulk-load** synthetic data.

Use it when you want a fast loop on real stacks before porting flows into Instruqt.

## What gets automated

| Step | Script |
| ---- | ------ |
| Validate Cloud API key | `scripts/00-check-prereqs.sh` |
| Create both serverless projects + wait for `initialized` | `scripts/01-provision-serverless.sh` |
| Create scoped **Elasticsearch** API keys (admin bootstrap only) | `scripts/02-create-es-api-keys.sh` |
| Apply templates + load `workshop-synth-*` data | `scripts/03-populate-indices.sh` |
| Print Kibana URLs + next steps | `scripts/04-print-next-steps.sh` |
| All of the above | `scripts/run-all.sh` |

## What stays manual (for now)

**Agent Builder** agents are authored in **Kibana** in each project. There is no stable, documented “create this agent from JSON” API in this repo. After the stack is live, follow the scaffolds under `../elastic-agent-builder-a2a-workshop/agent-scaffolds/` and the checklist in `AGENT_BUILDER.md` in this folder.

Later you can port the same story into Instruqt once the Kibana steps are stable.

## Prerequisites

- `curl`, `jq`, `bash`
- An Elastic Cloud **organization API key** with permission to create serverless projects (**Project Admin** / **Org owner** tier — see Elastic docs for your org).
- Do **not** paste secrets into chat; keep them in a local `.env` file.

### Aligning with Elastic agent skills

These skills describe the same operations this path automates via REST:

- **cloud-setup** — `EC_API_KEY`, `EC_BASE_URL`, `EC_REGION`, validate with `/api/v1/serverless/regions`
- **cloud-create-project** — equivalent to `01-provision-serverless.sh` (this repo uses `POST /api/v1/serverless/projects/{observability|security}`)
- **cloud-manage-project** — day-2 after projects exist (list/get/update/delete)

If your environment includes optional **`create-project.py`** / **`manage-project.py`** helpers that ship with some Elastic internal skill packs, you can create the two projects with those CLIs instead, then assemble `state/bootstrap.json` (endpoints + bootstrap credentials) yourself and start at **`02-create-es-api-keys.sh`**.

## Quick start

```bash
cd elastic-agent-builder-a2a-cloud-path
cp env.example .env
# edit .env — set EC_API_KEY (and optionally EC_REGION, A2A_NAME_PREFIX)

bash scripts/00-check-prereqs.sh
bash scripts/run-all.sh
```

Outputs (gitignored / sensitive):

- `state/bootstrap.json` — endpoints + **bootstrap credentials** (chmod `600`). Treat like `.elastic-credentials` in the skills: **do not commit**, do not use for routine ES traffic after API keys exist.
- `state/workshop.env` — `O11Y_*` and `SECURITY_*` URLs + **Elasticsearch API keys** for the workshop scripts (chmod `600`).

## Tightening API key privileges

`scripts/api-key-body.json` grants a **lab-wide** role for speed. Narrow `indices.names` and `privileges` before customer-facing demos.

## Troubleshooting

- **Security create returns 422** — the Cloud API may require extra fields over time. Compare your payload with the latest [Create security project](https://www.elastic.co/docs/api/doc/elastic-cloud-serverless/operation/operation-createsecurityproject) docs and extend `01-provision-serverless.sh`.
- **Elasticsearch `403` on `_security/api_key`** — confirm bootstrap `credentials` exist in `state/bootstrap.json` and that you are calling the **Elasticsearch** endpoint from that file, not Kibana.
