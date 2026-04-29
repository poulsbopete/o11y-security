# Scaffold: Observability context provider agent (Track 3)

Use **Agent Builder** in the **Serverless Observability** Kibana project.

## External contract

Expose an HTTP endpoint (Agent Builder webhook / custom integration) that accepts:

```json
{ "host": "prod-db-01", "time_range": "1m" }
```

## Queries (conceptual)

- **Metrics:** CPU, memory, disk read rate for `host.name == host` in `time_range`.
- **Traces / APM:** error rate and latency p95 for the same host and window.
- Derive booleans such as `error_rate_spike_detected` from a simple threshold policy (document thresholds in the agent notes).

## Response body (shape)

```json
{
  "host": "prod-db-01",
  "time_range": "1m",
  "metrics": {
    "cpu_percent": 85,
    "memory_percent": 72,
    "disk_io_read_mb_sec": 450
  },
  "traces": {
    "error_rate_percent": 12,
    "latency_p95_ms": 2400,
    "error_rate_spike_detected": true
  },
  "anomaly_detected": true,
  "context_summary": "High CPU + memory usage correlates with elevated error rate. Possible resource bottleneck."
}
```

## Lab data

Synthetic documents are loaded into `workshop-synth-metrics` and `workshop-synth-traces` by `scripts/load-sample-bulk.sh` so the agent has material to summarize even before full APM wiring. Bulk docs include **`workshop.demo_stream`** (`web` on traces, `os` on metrics) for the dual-mission facilitator narrative—see **[`../elastic-agent-builder-a2a-cloud-path/DUAL-MISSION-DEMO.md`](../elastic-agent-builder-a2a-cloud-path/DUAL-MISSION-DEMO.md)**.

## API documentation artifact

Save a short contract file the Security agent team can read:

`/root/elastic-workshop/artifacts/o11y-agent-contract.md` (create in Track 3 challenge).
