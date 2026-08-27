# Scaffold: Observability code-research agent (Sourcerer-like)

Use **Agent Builder** in **Serverless Observability**, or run cloud-path **`scripts/05-agent-builder-lab-agents.sh`** (creates **`a2a-lab-observability-code`**) plus **`scripts/11-index-sourcecode.sh`**.

## Data

- Index: **`workshop-synth-sourcecode`** (from `scripts/index-lab-sourcecode.sh`).
- Optional: official **[Sourcerer](https://github.com/elastic/sourcerer)** agent after `sourcerer setup` / `sourcerer index` against `poulsbopete/o11y-security` `main` (see `elastic-agent-builder-a2a-cloud-path/sourcerer.yml`).

## Example prompts

- Where is `LAB_VULN:sql_injection`? Cite `file.path`.
- How should `lookup_claim` bind `claim_id` instead of concatenating SQL?
- Why do credential-stuffing events on `prod-db-01` line up with slow 401 traces for `claims-portal`?

## Fix artifact (Instruqt)

`/root/elastic-workshop/artifacts/code-findings.md` — challenge **07** check.
