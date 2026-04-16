---
slug: response-agent-optional
type: challenge
title: "Challenge: Build a Response Agent (Optional)"
teaser: Close the loop with Slack, automation, or forensics storytelling.
tabs:
  - title: Serverless Observability
    type: service
    hostname: workstation
    port: 8080
    protocol: http
    new_window: true
  - title: Serverless Security
    type: service
    hostname: workstation
    port: 8081
    protocol: http
    new_window: true
  - title: Terminal
    type: terminal
    hostname: workstation
    workdir: /root/elastic-workshop
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
