# Agent Builder checklist (post-bootstrap)

After `scripts/run-all.sh`, you have live Elasticsearch + Kibana in **two** projects. Build agents in this order:

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
