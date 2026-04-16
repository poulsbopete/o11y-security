# Agent Builder checklist (post-bootstrap)

After your environment is live (via **[Elastic Agent Skills](https://github.com/elastic/agent-skills)** — **kibana-agent-builder** — or after `scripts/run-all.sh`), you have Elasticsearch + Kibana in **two** projects.

**This checklist is the A2A bridge:** separate projects stay separate; **Security enrichment** reaches **Observability** only by calling the **published Observability agent URL** over HTTPS (**`O11Y_AGENT_ENDPOINT`**). Kibana **synth inject** and **alert → workflow → case** automation support the demo but are **not** that cross-project call—wire enrichment below.

If **`scripts/05-agent-builder-lab-agents.sh`** ran (Node + `agent-builder.js` available; not skipped with `A2A_SKIP_AGENT_BUILDER=1`), starter agents may already exist on **both** Serverless Kibanas—see **`state/agent-builder-lab.json`**:

- **`a2a-lab-security-detection`** and **`a2a-lab-security-a2a-enrichment`** (Security)
- **`a2a-lab-observability-context`** (Observability)

Set **`O11Y_AGENT_ENDPOINT`** in **`state/workshop.env`** to your published Observability agent URL, then re-run **`05`** so enrichment instructions embed the live endpoint (or update the enrichment agent in Kibana). Refine agents with **kibana-agent-builder** as needed.

Build out the full story in this order:

> **Note:** `GET …` / JSON snippets in this file are for **Kibana Dev Tools (Console)**. Pasting them into **zsh** or **bash** will cause parse errors (`{` / `}` are shell syntax).

## 1. Security project (detection)

1. Open **Security** Kibana URL from `scripts/04-print-next-steps.sh` output.
2. **Agent Builder** → create a detection-style agent using `../elastic-agent-builder-a2a-workshop/agent-scaffolds/security-detection-agent.md`.
3. Route output to **`.elastic-agents-security-detections`**.
4. Confirm documents (Dev Tools):

```text
GET .elastic-agents-security-detections/_search
{
  "size": 1,
  "sort": [{ "@timestamp": "desc" }]
}
```

Synthetic endpoint-style rows are already in **`workshop-synth-endpoint-alerts`** on the Security cluster from the bulk loader.

## 2. Observability project (context provider)

1. Open **Observability** Kibana URL.
2. Build the HTTP contract from `../elastic-agent-builder-a2a-workshop/agent-scaffolds/observability-context-agent.md`.
3. Expose a URL the Security cluster can reach (public Agent Builder endpoint, approved proxy, etc.).
4. Append `O11Y_AGENT_ENDPOINT=...` to `state/workshop.env` (same file used for `O11Y_ES_URL` / `O11Y_API_KEY`).

Metrics/traces samples are in **`workshop-synth-metrics`** and **`workshop-synth-traces`** on the Observability cluster.

## 3. Security project (A2A enrichment)

1. Extend the Security workflow per `../elastic-agent-builder-a2a-workshop/agent-scaffolds/security-a2a-enrichment-workflow.md`.
2. Index to **`.elastic-agents-security-a2a-enriched`**.
3. Validate:

```text
GET .elastic-agents-security-a2a-enriched/_search
{
  "query": { "match": { "correlated_anomalies": "high_cpu" } }
}
```

## 4. Dashboard (optional)

Build in Security Kibana using the ES|QL starter in `../elastic-agent-builder-a2a-workshop/05-unified-dashboard/assignment.md`.

**Automated starter dashboards** (markdown + **Lens metric** panels backed by ad-hoc `data_view_spec` on workshop indices) are pushed with **`scripts/09-lab-dashboards-api.sh`** using the **Dashboards API** (`POST` / `PUT` **`/api/dashboards`** — do **not** use the `?apiVersion=` query string on Elastic Cloud Serverless; it is rejected). Dashboard ids are stored in **`state/kibana-dashboards-lab.json`**.

## 5. Whenever an “issue” fires: workflows, both projects, and Cases

You can make automation **visible** in two complementary ways: **Kibana Workflow run history** (steps, outputs, errors) and **Elastic Security Cases** (owners, comments, SLA, ITSM push).

### Concepts (do not conflate the two “workflow” words)

| Mechanism | What triggers it | Typical output |
| --------- | ------------------ | -------------- |
| **Agent Builder workflow** (Tracks 2–4) | Agent run / detection branch | Documents in **`.elastic-agents-*`** on the **Security** cluster; **HTTP** to the **Observability** published agent URL for A2A. |
| **Kibana Workflow** (alert trigger; Serverless / 9.3+) | **Alerting rule** when conditions match | Steps such as **`kibana.createCaseDefaultSpace`**, optional **`ai.prompt`**, **`kibana.request`**, plus (when available) outbound **HTTP** to published agent URLs. |

**Lab alert workflows (`kibana-workflows/yaml/*-alert-*.yaml`)** include an **`http`** step before **`kibana.createCaseDefaultSpace`**: **Security** workflows call **Observability** `POST …/api/agent_builder/converse` (agent **`a2a-lab-observability-context`**), and **Observability** workflows call **Security** `…/converse` (agent **`a2a-lab-security-detection`**). By default **`scripts/06-kibana-workflows-lab.sh`** derives each URL from **`state/bootstrap.json`** and injects **Basic** credentials for the *target* project’s Kibana admin (so you do not need **`O11Y_AGENT_ENDPOINT`** in **`workshop.env`** for the lab to run). Optional: set **`O11Y_AGENT_ENDPOINT`** / **`SECURITY_AGENT_ENDPOINT`** plus API keys in **`workshop.env`** to use published/custom invoke URLs instead (then **06** uses **ApiKey** auth for those steps). Re-run **06** after any change.

“**Both Serverless projects**” in customer language almost always means: **Security** runs the orchestration and **Cases**; **Observability** is **invoked over HTTP** from Security (same as [`../elastic-agent-builder-a2a-workshop/agent-scaffolds/security-a2a-enrichment-workflow.md`](../elastic-agent-builder-a2a-workshop/agent-scaffolds/security-a2a-enrichment-workflow.md)). A second workflow on the Observability Kibana is optional, not required for the A2A story.

### Bidirectional AI in Cases (Observability ↔ Security)

Your alert workflow can open a Case with **static** markdown (as in **`observability-alert-console.yaml`**) or with **live model text** by chaining steps before **`kibana.createCaseDefaultSpace`**:

1. **Same Kibana — `ai.agent`** — Invokes Agent Builder on **that** deployment (for example **`a2a-lab-observability-context`** on Observability, **`a2a-lab-security-a2a-enrichment`** on Security). Pass the alert as JSON in the **`message`**, then set the Case **`description`** to include **`{{ steps.<step_name>.output }}`**. See Elastic’s guide: [Call Elastic Agent Builder agents from Elastic Workflows](https://www.elastic.co/docs/explore-analyze/ai-features/agent-builder/agents-and-workflows).
2. **Cross Kibana — not `ai.agent`** — The other project’s agents are on a **different** Kibana origin. Use a **published agent HTTPS URL** (Security → **`O11Y_AGENT_ENDPOINT`** in **`state/workshop.env`** + enrichment instructions; Observability → optional **`http`** step to a published Security agent) or keep a **single orchestrator** (often Security) that performs one outbound HTTP and merges both sides into one Case.
3. **LLM without Agent Builder** — Use **`ai.prompt`** with an inference connector if you only need a short summary, then reference that step’s output in the Case description.

Step-by-step YAML patterns (trim payloads, handle failures, Case **`owner`**): **[`../elastic-agent-builder-a2a-workshop/agent-scaffolds/kibana-workflow-ai-agent-bidirectional-case.md`](../elastic-agent-builder-a2a-workshop/agent-scaffolds/kibana-workflow-ai-agent-bidirectional-case.md)**.

### Recommended patterns

1. **Fast path (workshop-aligned)** — Keep Agent Builder A2A as today, then add a **rule on `.elastic-agents-security-a2a-enriched`** (or on `workshop-synth-endpoint-alerts`) with the **Cases** system action and a markdown **description template** that states explicitly: Security agent steps, Observability HTTP call, target index, and links. Scaffold: [`../elastic-agent-builder-a2a-workshop/agent-scaffolds/alert-to-case-with-dual-project-audit.md`](../elastic-agent-builder-a2a-workshop/agent-scaffolds/alert-to-case-with-dual-project-audit.md).

2. **Maximum clarity for demos** — Add a **Kibana Workflow** with an **`alert`** trigger: rule fires → (optional) dual HTTP to published agents → **`kibana.createCaseDefaultSpace`** whose `description` is built from step outputs so the Case **is** the audit log. Same scaffold file lists **Option A** (YAML-oriented) and caveats. See Elastic Agent Skills **kibana-alerting-rules** (*Triggering Kibana Workflows from Rules*) and **kibana-connectors** (`references/workflows.md`). This repo can **push** starter alert workflows to both Kibanas with **`scripts/06-kibana-workflows-lab.sh`** (YAML under [`kibana-workflows/yaml/`](./kibana-workflows/yaml/)); attach **A2A Lab — O11y alert log** or **A2A Lab — alert audit (console)** to lab rules in the Kibana UI — each runs **console logging plus `createCase`** in one workflow (so you do not need a second “alert to Case” action on the same rule). To get **alerts** from existing workshop indices (ES|QL alone does not), run **`scripts/07-lab-alert-rules.sh`**; to **run** a workflow immediately without waiting for the scheduler, use **`scripts/08-synthetic-workflow-test.sh`**.

3. **Scripted / CI** — Create Cases via the **Cases API** or **`case_manager`** after scripted `curl` calls to both agents; use the same markdown template for the `description` field.

### Field tips

- Use **Elasticsearch query** rules when the workflow or Case template needs **document fields** (for example `host.name`) that threshold alerts do not surface.
- On failure, still open or update the Case with **what was attempted** (timeout, HTTP status) so “what happened” stays honest.
