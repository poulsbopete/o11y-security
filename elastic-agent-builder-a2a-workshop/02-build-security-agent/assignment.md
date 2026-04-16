---
slug: build-security-agent
type: challenge
title: "Build Your First Security Agent"
teaser: Author a detection agent that emits standardized events to a dedicated index.
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

# Build Your First Security Agent

This agent is the **brain**: it turns noisy endpoint activity into a crisp security object the business can reason about.

## Steps

1. Open **Kibana → Agent Builder** from the **Serverless Security** tab (same reverse-proxy host as Observability; port **8081**).
2. Create a **detection** style agent that:
   - Listens for endpoint-style authentication failures (`workshop-synth-endpoint-alerts` in the lab, or Fleet indices in the field).
   - Flags **high risk** when `failure_count > 5` in **1 minute** for a single `host.name`.
   - Emits the JSON shape in `agent-scaffolds/security-detection-agent.md`.
3. Route agent output to **`.elastic-agents-security-detections`**.
4. Run the agent once against the synthetic data (or replay the generator query).

## Optional CLI verification

```bash
source /root/elastic-workshop/.env
curl -sS -H "Authorization: ApiKey $SECURITY_API_KEY" \
  "$SECURITY_ES_URL/.elastic-agents-security-detections/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '{"size":1,"sort":[{"@timestamp":"desc"}]}'
```

=== Facilitation note

Keep the payload strict: stable field names make Track 4 merges predictable for demos.

===

Click **Check** after at least one detection document exists.
