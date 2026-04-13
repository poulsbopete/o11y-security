# Scaffold: Security detection agent (Track 2)

Use **Agent Builder** in the **Serverless Security** Kibana project.

## Inputs

- Primary signal: Endpoint / authentication failures (Fleet indices or `workshop-synth-endpoint-alerts` for lab bulk data).
- Window: rolling **1 minute** per host.

## Logic (pseudocode)

1. Aggregate failed authentication attempts **by `host.name`** in the last minute.
2. If `failure_count > 5`, emit a **standardized security payload** (single document).

## Output document (shape)

```json
{
  "event_id": "suspicious-login-attempt-12345",
  "severity": "high",
  "event_type": "authentication_failure",
  "host_name": "prod-db-01",
  "failure_count": 6,
  "time_window_minutes": 1,
  "@timestamp": "2026-04-13T15:22:00Z",
  "correlation_token": "<uuid>"
}
```

## Index

Write detections to **`.elastic-agents-security-detections`** (create via template + first document, or Agent Builder output routing).

## Test checklist

- [ ] Agent runs on a schedule or stream without errors
- [ ] At least one document visible in Discover for `.elastic-agents-security-detections`
- [ ] `correlation_token` populated for downstream A2A calls
