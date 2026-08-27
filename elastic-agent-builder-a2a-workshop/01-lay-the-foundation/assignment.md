---
slug: lay-the-foundation
id: 8ocnhl0wsjmo
type: challenge
title: Lay the Foundation
teaser: Confirm two Serverless projects (Observability + Security) and Elasticsearch
  API connectivity from the lab shell.
notes:
- type: text
  contents: |
    <iframe src="https://o11y-security.vercel.app/wait"
      width="100%" height="1400" frameborder="0"
      style="border-radius:8px;display:block;width:100%;min-height:900px;aspect-ratio:16/9;border:0"
      title="Observability and Security story deck"></iframe>
tabs:
- id: hruyzar9dqsn
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
- id: i2fyz27ttjto
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
- id: ipwlqlex1ab9
  title: Terminal
  type: terminal
  hostname: es3-api
  workdir: /root/elastic-workshop
difficulty: ""
enhanced_loading: null
---

# Lay the Foundation

In production, Security and Observability often run on separate clusters. This workshop keeps that split while teaching agents to cooperate over HTTPS APIs.

The **Serverless Observability** and **Serverless Security** tabs are both served through the same **es3-api** lab host: nginx listens on **8080** (Observability Kibana) and **8081** (Security Kibana) and reverse-proxies to the real Cloud URLs. There is still **one** sandbox VM — two **Cloud Serverless projects** behind it.

## Auto-provision (default)

**You do not need two VMs.** One **`es3-api`** host is enough: nginx on **8080** / **8081** reverse-proxies to two Cloud Serverless Kibanas.

When the track secret **`ESS_CLOUD_API_KEY`** is bound (Sandbox → Secrets), setup creates:

1. One **Observability** Serverless project
2. One **Security** Serverless project

Then it writes **`/root/elastic-workshop/.env`**, renders the nginx proxy, and loads workshop sample data. That can take **several minutes** — browse the story deck in assignment **Notes** (same slides as [o11y-security.vercel.app/wait](https://o11y-security.vercel.app/wait)) while you wait.

While tabs show plain text, they are serving the live status file (auto-refresh ~15s):

```bash
cat /root/elastic-workshop/provision-status.txt
tail -50 /root/elastic-workshop/provision.log
```

When setup finishes:

```bash
# Credentials + endpoints (chmod 600)
ls -la /root/elastic-workshop/.env /root/elastic-workshop/kibana-login.txt

# Reload the Kibana tabs (or click the refresh icon). Sign in with the users
# listed in kibana-login.txt if prompted.
source /root/elastic-workshop/.env
curl -sS -H "Authorization: ApiKey $O11Y_API_KEY" "$O11Y_ES_URL/_cluster/health" | jq .
curl -sS -H "Authorization: ApiKey $SECURITY_API_KEY" "$SECURITY_ES_URL/_cluster/health" | jq .
```

If the tabs still show status text after setup finished, re-run provision (idempotent when `.env` is complete):

```bash
bash /root/elastic-workshop/scripts/provision-dual-serverless.sh
```

## BYO fallback

If Cloud provision was skipped or the API key is missing, create **two** Serverless projects yourself, copy `env.template` → `.env`, then:

```bash
sudo bash /root/elastic-workshop/scripts/render-kibana-proxy.sh
bash /root/elastic-workshop/scripts/apply-index-templates.sh
bash /root/elastic-workshop/scripts/load-sample-bulk.sh
bash /root/elastic-workshop/scripts/index-lab-sourcecode.sh
```

=== Context

This track mirrors real field architecture: independent control planes, one-way API enrichment, and a unified narrative in Kibana for sellers to articulate value. Ending the Instruqt session deletes both Cloud projects when bootstrap state exists.

===

When both health calls return `"status": "green"` or `"yellow"`, and the **Serverless** tabs show Kibana **Dashboards**, click **Check**.
