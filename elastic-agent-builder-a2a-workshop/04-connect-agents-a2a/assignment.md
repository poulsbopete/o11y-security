---
slug: connect-agents-a2a
id: wemsrpzczgdx
type: challenge
title: 'Connect Agents: Implement A2A Communication'
teaser: Extend the Security workflow to call Observability and persist enriched incidents.
tabs:
- id: u8eqzyzaz22t
  title: Serverless Observability
  type: service
  hostname: es3-api
  path: /app/dashboards#/list?_g=(filters:!(),refreshInterval:(pause:!f,value:30000),time:(from:now-30m,to:now))
  port: 8080
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
- id: 1rt3sxe7gx51
  title: Serverless Security
  type: service
  hostname: es3-api
  path: /app/dashboards#/list?_g=(filters:!(),refreshInterval:(pause:!f,value:30000),time:(from:now-30m,to:now))
  port: 8081
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
- id: ywywmlhstzm7
  title: Terminal
  type: terminal
  hostname: es3-api
  workdir: /root/elastic-workshop
difficulty: ""
enhanced_loading: null
---

# Connect Agents: Implement A2A Communication

This is where **Security** asks **Observability** for context before committing the story to an index executives can consume.

## Steps

1. Re-open the Security detection workflow from Track 2.
2. After the high-severity branch triggers, insert an HTTP step that:
   - `POST` `${O11Y_AGENT_ENDPOINT}`
   - JSON body includes `host` (from the security event) and `time_range` (`1m` is fine for the lab).
   - Captures `a2a_response_time_ms`.
3. Merge the JSON bodies following `agent-scaffolds/security-a2a-enrichment-workflow.md`.
4. Index the enriched payload into **`.elastic-agents-security-a2a-enriched`**.

## Reference query

```
GET .elastic-agents-security-a2a-enriched/_search
{
  "query": {
    "match": {
      "correlated_anomalies": "high_cpu"
    }
  }
}
```

=== Facilitation note

If enrichment latency exceeds five seconds, narrate region placement, egress paths, and PrivateLink as mitigation levers.

===

Click **Check** once `correlated_anomalies` contains `high_cpu`.
