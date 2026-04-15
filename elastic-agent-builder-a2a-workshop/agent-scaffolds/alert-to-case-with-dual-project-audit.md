# Scaffold: When an issue fires → touch both projects → open a Case with an audit trail

Use this when you want **repeatable demos** where an “issue” is visible in Kibana, **both** Serverless projects participate (Security + Observability), and a **Security Case** reads like a **runbook**: what triggered, what ran where, and what came back.

## How “both projects” usually appear

| Project | Role in automation |
| ------- | ------------------- |
| **Security** | Where **Cases** live; where **detection / enrichment** Agent Builder agents run; where enriched docs land (e.g. `.elastic-agents-security-a2a-enriched`). |
| **Observability** | **Called from Security** over **HTTP** to the **published** Observability Agent Builder agent URL (`O11Y_AGENT_ENDPOINT`) — same A2A pattern as [`security-a2a-enrichment-workflow.md`](./security-a2a-enrichment-workflow.md). |

You normally **do not** need a second workflow definition on the Observability Kibana unless you are deliberately mirroring automation there.

---

## Option A — **Kibana Workflow** driven by an **alerting rule** (good for “whenever this issue is seen”)

**Preview:** Kibana Workflows and **rule → workflow** actions are available from **Elastic Stack 9.3** and **Elastic Cloud Serverless**; YAML and step types can evolve — confirm labels in **Stack Management → Workflows** for your build.

1. **Rule** — Create a rule whose condition is your definition of “issue”, for example:
   - **Elasticsearch query** on `workshop-synth-endpoint-alerts`, or
   - **Elasticsearch query** on `.elastic-agents-security-detections` / `.elastic-agents-security-a2a-enriched` after Agent Builder has written rows.

   Prefer **ES Query** rules if you need **rich source fields** (e.g. `host.name`) inside the workflow; some threshold-style alerts expose **limited** fields in `event.alerts[0]`.

2. **Workflow** — Create a workflow with an **`alert`** trigger. Chain steps roughly as:
   - **Optional:** `ai.prompt` to summarize `{{ event.alerts[0].kibana.alert.reason }}` (or full `{{ event | json:2 }}` for debugging).
   - **Agent calls:** Use your Kibana version’s **outbound HTTP** (or equivalent) steps to POST JSON to:
     - the **published Security** agent URL (only if you need an explicit second model pass on Security), and
     - **`O11Y_AGENT_ENDPOINT`** for Observability context (`host`, `time_range`, etc.).
   - If outbound HTTP steps are not available yet, keep **both** agent calls inside **Agent Builder** on Security (Option B) and use this workflow only for **Case creation** plus static audit lines.

3. **Case** — Add a step **`kibana.createCaseDefaultSpace`** (see Elastic **kibana-connectors** reference *Workflows* → alert trigger examples) with:
   - `title` including rule name and host (or entity),
   - `description` built from prior step outputs so it **names each call** (HTTP status, latency, truncated JSON) and the **merge** result.
   - **Schema gotcha:** the step’s `with` block must include **`owner`** (`securitySolution` vs `observability`), **`settings.syncAlerts`** (boolean), and for a no-connector case **`connector.fields`** (often `null`) alongside `id` / `name` / `type: ".none"`. Without these, Kibana may save the workflow as **invalid** / “Untitled”. Working YAML examples: **[`elastic-agent-builder-a2a-cloud-path/kibana-workflows/yaml/`](../elastic-agent-builder-a2a-cloud-path/kibana-workflows/yaml/)** (created by **`06-kibana-workflows-lab.sh`**).

4. **Rule action** — On the rule, add the **Workflow** action; use `params: {}` so the alert payload flows into `event` (see Elastic **kibana-alerting-rules** skill: *Triggering Kibana Workflows from Rules*). **Only `enabled: true` workflows** appear in the picker.

5. **Deduping** — For high-volume signals, group Cases by **`host.name`** (or service) in the rule’s Case settings so you do not open hundreds of Cases.

---

## Option B — **Agent Builder** (this workshop) + **Cases** rule action (minimal moving parts)

Best when you want the **story in Agent Builder** (detection → HTTP to Observability → merge → index) and Cases only for **SOC ownership**.

1. Complete **Track 2–4** so enrichment writes **`.elastic-agents-security-a2a-enriched`** with `o11y_context`, `correlated_anomalies`, `a2a_response_time_ms`, etc.

2. Create a **Security** (or stack) **rule** that fires when those fields indicate a real incident (ES query on `.elastic-agents-security-a2a-enriched`).

3. In the rule UI, add the **Cases** system action and paste a **description template** that explicitly states:
   - the rule name and reason,
   - that the **Security** Agent Builder workflow ran,
   - that **Observability** was consulted via **`O11Y_AGENT_ENDPOINT`**,
   - where to open **Discover** / Dev Tools for the same `@timestamp` / `host.name`.

Use the **Mustache / Markdown template** in the section below.

---

## Option C — **Cases API** or **`case_manager`** (scripted demos)

Use the Kibana **Cases API** (or Elastic Agent Skills **security-case-management**) to create a Case whose `description` is a full markdown audit **after** your script has called both agent HTTP endpoints with `curl`. Good for **recorded** or **CI** demos; not a substitute for per-alert automation.

---

## Case description template (copy and adapt)

Use in **Cases** rule actions, **`kibana.createCaseDefaultSpace`**, or API `description`. Replace Mustache paths with fields your rule actually exposes (`context.*` vs `event.alerts[0].*`).

```markdown
## Automated triage

**When:** {{{date}}}  
**Trigger:** {{{rule.name}}} — {{{context.reason}}}  
**Entity:** {{{event.alerts.0.host.name}}} _(or the field your ES query rule maps into the alert)_

### What ran (Security project)

- Agent Builder **detection / enrichment** workflow evaluated against Security-cluster data.
- Enriched incidents (if present): index **`.elastic-agents-security-a2a-enriched`** on the Security Elasticsearch deployment.

### What ran (Observability project)

- **HTTP POST** to the published Observability Agent Builder endpoint (**`O11Y_AGENT_ENDPOINT`**), using `host` + `time_range` from the security-side event.
- Response fields merged into the enrichment document (`o11y_context`, `correlated_anomalies`, `a2a_response_time_ms`).

### Traceability

- **Rule id:** {{{rule.id}}}  
- **Alert id:** {{{alert.id}}}  
- **Deep link:** {{{rule.url}}}

_Add workflow step outputs here when using Kibana Workflows: HTTP status lines, latency ms, and one-line summaries of each agent response._
```

---

## Facilitation notes

- **Workflows are easy to show** because Kibana surfaces **run history** and step outputs; pairing that with a **Case** gives executives both **narrative** (Case) and **technical replay** (workflow + indices).
- **Credentials:** HTTP steps to Agent Builder URLs must use headers your published endpoints require; never embed live API keys in Case text — reference **connector secrets** or “stored in Stack Management”.
- **Honest boundary:** If a step fails, write the failure into the Case description (`o11y_context: null`, timeout) so the Case still explains **what was attempted**.
