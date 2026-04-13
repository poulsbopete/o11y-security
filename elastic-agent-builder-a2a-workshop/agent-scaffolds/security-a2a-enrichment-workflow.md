# Scaffold: Security → Observability A2A enrichment (Track 4)

Still in **Serverless Security** Agent Builder — extend the detection workflow with an HTTP call to the Observability agent.

## Pseudocode

```
Step 1: Detect suspicious behavior
  → Parse source signal; if failure_count > 5 in 1m for a host, build base security event.

Step 2: Call Observability agent
  → POST ${O11Y_AGENT_ENDPOINT}
  → JSON body: { "host": "<host_name>", "time_range": "1m" }
  → Timeout: 5 seconds; record a2a_response_time_ms

Step 3: Enrich & correlate
  → Merge security event + Observability JSON
  → correlated_anomalies: derive labels (examples: high_cpu, high_memory, elevated_errors)
  → requires_investigation: true when severity is high AND anomaly_detected is true

Step 4: Output
  → Index document to `.elastic-agents-security-a2a-enriched`
```

## Example enriched fields

- `o11y_context`: raw JSON from the Observability agent
- `correlated_anomalies`: keyword array
- `a2a_response_time_ms`: number

## Validation query (Dev Tools)

```
GET .elastic-agents-security-a2a-enriched/_search
{
  "query": { "match": { "correlated_anomalies": "high_cpu" } }
}
```

## Failure modes to discuss in workshop

- Cross-cluster latency > 5s (hint learners to check region alignment and private connectivity options)
- 401/403 from Observability endpoint (scoped keys and URL typos)
- Partial JSON — decide whether to still emit security-only event with `o11y_context: null`
