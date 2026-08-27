# Acme Claims Portal (lab only)

Intentionally flawed sample service for the **Observability + Security** workshop. **Do not deploy this code.** The runtime **Chaos Console** (`chaos_ui.py`) does **not** execute the vulnerabilities: it only injects synthetic telemetry that matches what those bugs would look like in production.

| File | Role |
| ---- | ---- |
| `claims_portal.py` | Fake claims/login handlers with `LAB_VULN:` markers (SQL concatenation, debug dump). |
| `config.py` | Hardcoded lab secrets (`LAB_VULN:hardcoded_secret`). |
| `chaos_ui.py` | HTTP console (default port **8082**) that bursts Security + Observability workshop indices. |
| `static/index.html` | Learner UI: healthy traffic vs credential stuffing vs SQLi-shaped noise vs debug leak. |

Index these sources into **Observability** Elasticsearch (`workshop-synth-sourcecode`) with `scripts/index-lab-sourcecode.sh`, or run **[elastic/sourcerer](https://github.com/elastic/sourcerer)** against `github.com/poulsbopete/o11y-security` (see cloud-path `sourcerer.yml` and `scripts/11-index-sourcecode.sh`).
