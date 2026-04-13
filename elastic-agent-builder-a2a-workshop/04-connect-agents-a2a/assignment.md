---
slug: connect-agents-a2a
type: challenge
title: "Connect Agents: Implement A2A Communication"
teaser: Extend the Security workflow to call Observability and persist enriched incidents.
tabs:
  - title: Terminal
    type: terminal
    hostname: workstation
    workdir: /root/elastic-workshop
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
