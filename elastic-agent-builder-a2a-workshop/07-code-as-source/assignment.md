---
slug: code-as-source
id: 3op5cinalhbo
type: challenge
title: 'Code as source: detect and fix issues'
teaser: Index the claims portal with Sourcerer-style code search, generate live noise,
  then cite and remediate LAB_VULN findings.
tabs:
- id: gi2dkq2cevfz
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
- id: a9b9stukrycr
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
- id: tf3ilnvatwwu
  title: Chaos Console
  type: service
  hostname: es3-api
  path: /
  port: 8082
- id: 9gwtbrentdw1
  title: Terminal
  type: terminal
  hostname: es3-api
  workdir: /root/elastic-workshop
difficulty: ""
enhanced_loading: null
---

# Code as source: detect and fix issues

This challenge is the **O11y ↔ Security** punchline for practitioners who live in one domain:

- **Observability person:** the repo is another telemetry plane. Code explains *why* `prod-db-01` is slow or throwing 401/5xx — not just that it is.
- **Security person:** live auth noise is stronger when you can **cite the handler** (SQL concatenation, hardcoded secrets, unauthenticated debug) instead of arguing from logs alone.

We use **[elastic/sourcerer](https://github.com/elastic/sourcerer)** when `uv` is available (cloud path **`scripts/11-index-sourcecode.sh`**), and a **Sourcerer-like** bulk index of `lab-app/` into **`workshop-synth-sourcecode`** so Instruqt sandboxes stay fast. Both put the **same planted `LAB_VULN:` markers** in Elasticsearch for Agent Builder to grep.

The **Chaos Console** tab does **not** run the bugs. It injects synthetic Security + Observability events that *look like* those bugs firing (credential stuffing → failed logins + slow 401s; SQLi-shaped probes → 5xx + high latency — the joint signal is the point).

## Steps

1. On **Terminal**, confirm `.env` exists, then index the claims portal source onto **Observability** Elasticsearch (mirrors to Security unless you skipped that):

```bash
bash /root/elastic-workshop/scripts/index-lab-sourcecode.sh
```

2. Optional (cloud / facilitator laptop with `uv`): from the repo’s `elastic-agent-builder-a2a-cloud-path` folder, `bash scripts/11-index-sourcecode.sh` so Sourcerer clones `poulsbopete/o11y-security` `main` into the Observability cluster. In Kibana **Agents**, you should then see a **Sourcerer** agent in addition to the lab context agent.

3. Open **Chaos Console** and click **Generate stuffing noise** (then optionally **SQLi-shaped**). Reload **Discover** on both Kibanas for `prod-db-01` / `workshop.attack_kind`.

4. **Observability Agent Builder** — ask (context agent, code-source agent, or Sourcerer):

   - Where is `LAB_VULN:sql_injection` in the claims portal? Cite `file.path`.
   - Why would credential stuffing raise **both** login failures and transaction latency/401s?
   - What should we change so `claim_id` is not concatenated into SQL?

5. **Security Agent Builder** — ask the detection or enrichment agent to correlate the new `workshop-synth-endpoint-alerts` burst with Observability context, and to name the source file in `workshop.source_file`.

6. Write remediations to **`/root/elastic-workshop/artifacts/code-findings.md`**. The check looks for all of:

   - `sql_injection` or `parameterized`
   - `hardcoded` or `secret`
   - `claims_portal.py`

## Why this matters (talk track)

**Observability:** a single latency detector says the service is “bad.” Latency **plus** 401/5xx in the same window tells you *how* it is bad — capacity vs broken vs abuse.

**Security:** stuffing or enumeration is a stronger story when the same window shows slow failed transactions **and** you can point at the login SQL in git.

Click **Check** when the findings file exists.
