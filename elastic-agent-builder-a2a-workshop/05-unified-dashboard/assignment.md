---
slug: unified-dashboard
id: oyl2nze7v9ih
type: challenge
title: 'Visualize & Respond: Build the Unified Dashboard'
teaser: Tell the joint Security + Observability story inside Kibana.
tabs:
- id: xkmdm03gkoym
  title: Serverless Observability
  type: service
  hostname: es3-api
  path: /app/dashboards#/list?_g=(filters:!(),refreshInterval:(pause:!f,value:30000),time:(from:now-30m,to:now))
  port: 8080
  protocol: http
  custom_request_headers:
  - key: Content-Security-Policy
    value: 'script-src ''self'' https://kibana.estccdn.com; worker-src blob: ''self'';
      style-src ''unsafe-inline'' ''self'' https://kibana.estccdn.com; style-src-elem
      ''unsafe-inline'' ''self'' https://kibana.estccdn.com'
  custom_response_headers:
  - key: Content-Security-Policy
    value: 'script-src ''self'' https://kibana.estccdn.com; worker-src blob: ''self'';
      style-src ''unsafe-inline'' ''self'' https://kibana.estccdn.com; style-src-elem
      ''unsafe-inline'' ''self'' https://kibana.estccdn.com'
- id: snjno0obkixv
  title: Serverless Security
  type: service
  hostname: es3-api
  path: /app/dashboards#/list?_g=(filters:!(),refreshInterval:(pause:!f,value:30000),time:(from:now-30m,to:now))
  port: 8081
  protocol: http
  custom_request_headers:
  - key: Content-Security-Policy
    value: 'script-src ''self'' https://kibana.estccdn.com; worker-src blob: ''self'';
      style-src ''unsafe-inline'' ''self'' https://kibana.estccdn.com; style-src-elem
      ''unsafe-inline'' ''self'' https://kibana.estccdn.com'
  custom_response_headers:
  - key: Content-Security-Policy
    value: 'script-src ''self'' https://kibana.estccdn.com; worker-src blob: ''self'';
      style-src ''unsafe-inline'' ''self'' https://kibana.estccdn.com; style-src-elem
      ''unsafe-inline'' ''self'' https://kibana.estccdn.com'
- id: mlklpsyik2qm
  title: Terminal
  type: terminal
  hostname: es3-api
  workdir: /root/elastic-workshop
difficulty: ""
enhanced_loading: null
---

# Visualize & Respond: Build the Unified Dashboard

## Steps (Kibana UI — Security project)

1. Create a dashboard named **Security + Observability Correlation**.
2. Add panels suggested in the workshop brief:
   - Detections by `severity`
   - Percent of documents with populated `o11y_context`
   - Top values of `correlated_anomalies`
   - Timeline of `@timestamp` vs `a2a_response_time_ms`
3. Enable a drill-down from a detection table into the full enriched document JSON.

## ES|QL starter

```
FROM .elastic-agents-security-a2a-enriched
| STATS
    event_count = COUNT(),
    avg_enrichment_latency_ms = AVG(a2a_response_time_ms),
    high_severity_with_correlation = COUNT_DISTINCT(
      CASE WHEN severity == "high" AND correlated_anomalies IS NOT NULL THEN correlation_token END
    )
  BY severity
| SORT event_count DESC
```

=== Hint

If `avg_enrichment_latency_ms` exceeds **5000**, narrate network distance, auth overhead, and PrivateLink as tuning paths.

===

## Proof artifact

Paste the Kibana dashboard **id** (from the URL) into `/root/elastic-workshop/artifacts/security-o11y-dashboard-id.txt` so facilitators can review your build.

Click **Check** once that file exists.
