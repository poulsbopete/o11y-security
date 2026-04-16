---
slug: response-agent-optional
id: 64rvhhirakis
type: challenge
title: 'Challenge: Build a Response Agent (Optional)'
teaser: Close the loop with Slack, automation, or forensics storytelling.
tabs:
- id: juymjqvmxmyt
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
- id: pmo9kmxhajqr
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
- id: e7k8ayj2jti0
  title: Terminal
  type: terminal
  hostname: es3-api
  workdir: /root/elastic-workshop
difficulty: ""
enhanced_loading: null
---

# Challenge: Build a Response Agent (Optional)

Pick **one** path:

=== Option A — Integration

Build a third agent (Security or Observability) that watches `.elastic-agents-security-a2a-enriched` for `severity: high` plus correlated anomalies, then posts a Slack message summarizing host, CPU, error rate, and login failures.

===

=== Option B — Automation

Author a workflow that would trigger an approved response action (scale, isolate, WAF toggle) **as a tabletop exercise**, and log the intent to **`.elastic-agents-response-log`**.

===

=== Option C — Investigation

Draft an ES|QL notebook that reconstructs **detection → Observability context → correlated anomalies** as a timeline suitable for leadership readouts.

===

## Proof artifact

Write your choice (`integration`, `automation`, or `investigation`) to `/root/elastic-workshop/artifacts/response-track-choice.txt` and add a one-line description of what you built.

Click **Check** to record completion.
