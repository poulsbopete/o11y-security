---
slug: build-observability-agent
id: qfpusbhx8ar4
type: challenge
title: Build Your Observability Agent (Context Provider)
teaser: Stand up an Observability-side agent that answers host + window questions
  over HTTP.
tabs:
- id: a3zc6xgickaq
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
- id: uezih5r8qhwz
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
- id: xcsvtzdddzna
  title: Terminal
  type: terminal
  hostname: es3-api
  workdir: /root/elastic-workshop
difficulty: ""
enhanced_loading: null
---

# Build Your Observability Agent (Context Provider)

This agent is the **eyes**: it pulls platform context without duplicating Security analytics.

## Steps

1. Open **Agent Builder** from the **Serverless Observability** tab (port **8080** on the lab nginx proxy).
2. Implement the contract described in `/root/elastic-workshop/agent-scaffolds/observability-context-agent.md`.
3. Expose an HTTPS endpoint your Security project can reach (public Agent Builder URL, reverse proxy, or approved integration pattern your team supports).
4. Add `O11Y_AGENT_ENDPOINT` to `/root/elastic-workshop/.env` (include path through `/query` if that is how you modeled the route).

## Document the contract

Create `/root/elastic-workshop/artifacts/o11y-agent-contract.md` summarizing:

- Authentication model (API key header name, mTLS, etc.)
- Request JSON fields
- Response JSON fields
- Example `curl` identical to what Security will run

## Suggested test

```bash
source /root/elastic-workshop/.env
curl -sS -X POST "$O11Y_AGENT_ENDPOINT" \
  -H "Authorization: ApiKey $O11Y_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"host":"prod-db-01","time_range":"1m"}' | jq .
```

If you receive JSON shaped like `sample-data/o11y-context-example.json`, you are ready for A2A wiring.

Click **Check** once the contract file exists and the endpoint responds.
