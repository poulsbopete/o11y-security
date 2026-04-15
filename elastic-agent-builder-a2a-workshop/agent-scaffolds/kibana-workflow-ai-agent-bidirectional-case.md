# Scaffold: Kibana Workflows + Agent Builder — bidirectional AI and richer Cases

Use this when you want **real model output** in the Case body (not only static markdown), and optionally **both** projects’ agents to contribute: **Observability** Kibana workflows calling the local context agent plus a **published** Security agent URL, and **Security** workflows or Agent Builder tracks calling **`O11Y_AGENT_ENDPOINT`**.

Confirm step names and privileges in **Stack Management → Workflows** for your Serverless build (preview APIs evolve). Official reference: [Call Elastic Agent Builder agents from Elastic Workflows](https://www.elastic.co/docs/explore-analyze/ai-features/agent-builder/agents-and-workflows).

## Same-Kibana reasoning: `ai.agent`

The **`ai.agent`** step runs an Agent Builder agent **on the same Kibana** as the workflow. Lab agent ids from **`scripts/05-agent-builder-lab-agents.sh`** (see **`state/agent-builder-lab.json`**):

| Kibana | `agent_id` (typical) | Role |
| ------ | -------------------- | ---- |
| Observability | `a2a-lab-observability-context` | Summarize metrics/traces for `host.name`, time window, alert reason. |
| Security | `a2a-lab-security-a2a-enrichment` | Correlate endpoint-style signals with Observability context (when HTTP tool targets **`O11Y_AGENT_ENDPOINT`**). |

**Pattern:** alert workflow steps = **`console`** (optional) → **`ai.agent`** with `message` built from `{{ event.alerts[0] | json:2 }}` (trim if too large) → **`kibana.createCaseDefaultSpace`** with `description` that **starts** with your audit table and **appends** `{{ steps.<ai_step_name>.output }}`.

Example shape (Observability — adjust step names and validate in the UI):

```yaml
steps:
  - name: o11y_agent_triage
    type: ai.agent
    with:
      agent_id: "a2a-lab-observability-context"
      message: |
        An Observability alerting rule fired. Using only workshop indices (workshop-synth-metrics,
        workshop-synth-traces), summarize likely user impact, cite host/service if present, and give 3 concrete next checks.
        Alert payload (JSON):
        {{ event.alerts[0] | json:2 }}
  - name: create_a_case
    type: kibana.createCaseDefaultSpace
    with:
      title: "{{ event.alerts[0].kibana.alert.rule.name }} — O11y triage (AI)"
      description: |
        ## Agent summary (Observability)
        {{ steps.o11y_agent_triage.output }}

        ## Rule / alert (verbatim context)
        | Field | Value |
        | --- | --- |
        | **Rule** | {{ event.alerts[0].kibana.alert.rule.name }} |
        | **Reason** | {{ event.alerts[0].kibana.alert.reason }} |
        | **Host** | {{ event.alerts[0].host.name }} |
      tags: ["a2a-lab", "workflow", "ai"]
      severity: "medium"
      owner: "observability"
      settings:
        syncAlerts: true
      connector:
        id: "none"
        name: "none"
        type: ".none"
        fields: null
```

Optional: add **`schema`** on **`ai.agent`** so the model returns JSON fields you map into markdown yourself.

## Cross-Kibana: Observability ↔ Security

- **`ai.agent`** does **not** call agents on the *other* Serverless project. For that you need either:
  - **`http`** steps to each project’s **published** Agent Builder HTTPS endpoint (and any required auth headers your deployment uses), or
  - **Agent Builder** tool / workflow on one agent that performs the outbound HTTP (this repo’s **`O11Y_AGENT_ENDPOINT`** pattern on **Security** enrichment).

**Symmetric env vars (conceptual):**

| Direction | Mechanism |
| --------- | --------- |
| Security → Observability | Security agent instructions + HTTP POST to **`O11Y_AGENT_ENDPOINT`** (see **`agent-instructions/security-a2a-enrichment.txt`** and **`security-a2a-enrichment-workflow.md`**). |
| Observability → Security | Publish a **Security** agent URL; from an **Observability** Kibana Workflow, add an **`http`** step `POST`ing `{ "host": "…", "alert_summary": "…" }` (match whatever contract you document on the Security agent). Store the URL outside YAML if it contains secrets, or use workflow **constants** / secrets features your build supports. |

If **`http`** to a second model is undesirable, keep **one** “orchestrator” side (often **Security** for SOC Cases) and only **invoke** the other stack over HTTP once, then merge into a single Case description.

## Alternative: `ai.prompt` + LLM connector

Use **`ai.prompt`** with a configured inference **connector** when you want a generic LLM summary without routing through Agent Builder tools. See Elastic **kibana-connectors** workflow examples (`ai.prompt` + **`kibana.createCaseDefaultSpace`** with `description: "{{ steps…output }}"`).

## Facilitation

- **Payload size:** trim `{{ event | json:2 }}` in the prompt (host, rule name, reason, one source document) so the agent step stays under context limits.
- **Failures:** add a **`console`** or branch so if **`ai.agent`** fails, the Case still opens with static fields + “AI step failed: …”.
- **Case owner:** Observability workflows should keep **`owner: observability`**; Security SOC Cases use **`securitySolution`** where applicable — match the team that owns the queue.
