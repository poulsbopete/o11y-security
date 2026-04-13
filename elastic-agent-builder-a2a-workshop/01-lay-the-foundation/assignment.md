---
slug: lay-the-foundation
type: challenge
title: "Lay the Foundation"
teaser: Create two Serverless projects and prove Elasticsearch API connectivity from the lab shell.
tabs:
  - title: Terminal
    type: terminal
    hostname: workstation
    workdir: /root/elastic-workshop
---

# Lay the Foundation

In production, Security and Observability often run on separate clusters. This workshop keeps that split while teaching agents to cooperate over HTTPS APIs.

## What you will do

1. In **Elastic Cloud**, create a **Serverless Observability** project and a **Serverless Security** project (separate Elasticsearch + Kibana per project).
2. Create an **Elasticsearch API key** in each project with privileges sufficient for `_cluster/health`, `_index_template`, `_bulk`, and `_search` on workshop indices used in later challenges (your SA can provide a least-privilege role matrix).
3. On the **Terminal** tab, copy the template and save credentials:

```bash
cp /root/elastic-workshop/env.template /root/elastic-workshop/.env
chmod 600 /root/elastic-workshop/.env
${EDITOR:-vi} /root/elastic-workshop/.env
```

4. (Recommended) Install index templates on the **Security** cluster and load synthetic workshop data:

```bash
bash /root/elastic-workshop/scripts/apply-index-templates.sh
bash /root/elastic-workshop/scripts/load-sample-bulk.sh
```

5. Verify both clusters with `curl` (Bearer token is the API key string):

```bash
curl -sS -H "Authorization: Bearer $O11Y_API_KEY" "$O11Y_ES_URL/_cluster/health" | jq .
curl -sS -H "Authorization: Bearer $SECURITY_API_KEY" "$SECURITY_ES_URL/_cluster/health" | jq .
```

=== Context

This track mirrors real field architecture: independent control planes, one-way API enrichment, and a unified narrative in Kibana for sellers to articulate value.

===

When both health calls return `"status": "green"` or `"yellow"`, click **Check**.
