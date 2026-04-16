---
slug: lay-the-foundation
id: 8ocnhl0wsjmo
type: challenge
title: Lay the Foundation
teaser: Create two Serverless projects and prove Elasticsearch API connectivity from
  the lab shell.
tabs:
- id: hruyzar9dqsn
  title: Serverless Observability
  type: service
  hostname: workstation
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
- id: i2fyz27ttjto
  title: Serverless Security
  type: service
  hostname: workstation
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
- id: ipwlqlex1ab9
  title: Terminal
  type: terminal
  hostname: workstation
  workdir: /root/elastic-workshop
difficulty: ""
enhanced_loading: null
---

# Lay the Foundation

In production, Security and Observability often run on separate clusters. This workshop keeps that split while teaching agents to cooperate over HTTPS APIs.

The **Serverless Observability** and **Serverless Security** tabs are both served through the same **workstation** host: nginx listens on **8080** (Observability Kibana) and **8081** (Security Kibana) and reverse-proxies to the real Cloud URLs you put in `.env`. Each tab opens the **Dashboards** list with **Content-Security-Policy** headers on the Instruqt proxy (request + response) so Kibana can load **inside the lab** (including `kibana.estccdn.com`).

## What you will do

1. In **Elastic Cloud**, create a **Serverless Observability** project and a **Serverless Security** project (separate Elasticsearch + Kibana per project).
2. Create an **Elasticsearch API key** in each project with privileges sufficient for `_cluster/health`, `_index_template`, `_bulk`, and `_search` on workshop indices used in later challenges (your SA can provide a least-privilege role matrix).
3. On the **Terminal** tab, copy the template and save credentials (include **both** Elasticsearch and **HTTPS Kibana base URLs** — from each project’s **Endpoints** page, same region as the `.es.` hostname):

```bash
cp /root/elastic-workshop/env.template /root/elastic-workshop/.env
chmod 600 /root/elastic-workshop/.env
${EDITOR:-vi} /root/elastic-workshop/.env
```

4. **Enable the Kibana tabs** — still on Terminal, render nginx from `.env` (requires `sudo` once per sandbox after Kibana URLs are set):

```bash
sudo bash /root/elastic-workshop/scripts/render-kibana-proxy.sh
```

5. (Recommended) Install index templates on the **Security** cluster and load synthetic workshop data:

```bash
bash /root/elastic-workshop/scripts/apply-index-templates.sh
bash /root/elastic-workshop/scripts/load-sample-bulk.sh
```

6. Verify both clusters with `curl` (use the `ApiKey` scheme with the base64 API key string):

```bash
curl -sS -H "Authorization: ApiKey $O11Y_API_KEY" "$O11Y_ES_URL/_cluster/health" | jq .
curl -sS -H "Authorization: ApiKey $SECURITY_API_KEY" "$SECURITY_ES_URL/_cluster/health" | jq .
```

=== Context

This track mirrors real field architecture: independent control planes, one-way API enrichment, and a unified narrative in Kibana for sellers to articulate value.

===

When both health calls return `"status": "green"` or `"yellow"`, and the **Serverless** tabs show Kibana **Dashboards** (sign in with the same credentials you use in Elastic Cloud if prompted), click **Check**.
