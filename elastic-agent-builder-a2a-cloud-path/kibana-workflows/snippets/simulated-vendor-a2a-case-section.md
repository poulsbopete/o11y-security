## Simulated third-party A2A corroboration (lab)

_The rows below **simulate** Alert→API enrichment calls to vendor backends from the “Elastic wins because our competitors lack depth” story (Observability, Security SIEM/XDR, and data lake / cloud retrieval). **No live credentials**—synthetic payloads for workshop demos and architecture discussion. Entity: **`{{ event.alerts[0].host.name }}`**._

### Observability platforms

| Backend | HTTP | ms | Simulated finding |
| --- | --- | ---: | --- |
| Datadog | 200 | 112 | APM service map: elevated p95 on checkout path; no new deploy in window. |
| Splunk (Cisco) | 200 | 178 | SPL pivot: auth failure spike correlated index matches same host slice. |
| New Relic | 200 | 95 | NRQL: throughput flat, error rate +0.4% vs 24h baseline. |
| Dynatrace | 200 | 134 | PurePath: downstream JDBC pool wait +220ms vs baseline. |
| Grafana / LGTM | 200 | 71 | Loki: burst of 429s from single pod; Mimir shows normal saturation. |
| AWS (CloudWatch / X-Ray) | 200 | 88 | X-Ray segment fault on dependency `payments-v2`; Lambda cold start ruled out. |

### Security platforms

| Backend | HTTP | ms | Simulated finding |
| --- | --- | ---: | --- |
| Palo Alto Networks | 200 | 156 | Cortex XDR: rare parent→child chain on host `{{ event.alerts[0].host.name }}`; low prevalence hash. |
| Splunk (Cisco) | 200 | 165 | Enterprise Security notable: same user session seen in two regions within 12m. |
| Rapid7 | 200 | 142 | InsightIDR: beaconing-like DNS cadence; confidence medium (lab). |
| CrowdStrike | 200 | 121 | Falcon: new unsigned module load adjacent to alert time; containment not requested. |
| SentinelOne | 200 | 109 | Storyline: cross-process activity flagged; rollback point available. |
| Microsoft Sentinel | 200 | 189 | KQL: `SigninLogs` + `Device*` join suggests impossible travel precursor (synthetic). |

### Data lake and cloud retrieval

| Backend | HTTP | ms | Simulated finding |
| --- | --- | ---: | --- |
| Snowflake | 200 | 203 | `QUERY_HISTORY`: warehouse credit bump +12% vs 7d avg; no full-table scan. |
| Databricks | 200 | 187 | Unity Catalog audit: notebook job read sensitive table outside SLA window (lab). |
| Microsoft Azure | 200 | 131 | Resource Graph: NSG flow log gap on subnet peer; Defender alert absent. |
| AWS | 200 | 124 | CloudTrail + GuardDuty: no HIGH findings; S3 data event volume nominal. |
| Google Cloud | 200 | 139 | Chronicle-style VPC flow summary: egress to unknown ASN short-lived (synthetic). |

_Use Elastic **Cases** as the merge surface: each vendor would normally be a separate connector, credential, and retention policy—here one workflow block illustrates the **audit trail** you want from real A2A._
