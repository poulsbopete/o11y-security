---
name: Observability-side scenario
about: Track an Observability-only lab story — SLOs, service health, errors, latency, or infra signals tied to the A2A Observability project.
title: "[Observability] "
labels: []
assignees: []
---

## Scenario summary

<!-- One paragraph: what the platform / SRE / app team cares about in this thread. -->

Example angles: **error-rate or latency SLO burn**, **dependency failures**, **noisy traces or logs**, **capacity or saturation**, or **correlating user-visible impact** to a time window for later Security handoff.

## Signals and indices

- **Indices** involved (e.g. `workshop-synth-metrics`, `workshop-synth-traces`, `workshop-synth-logs`):
- **Service / host / transaction** identifiers that should appear in alerts or cases:

## What we want to prove in Kibana

- [ ] Observability alerting rule or threshold behaves as expected
- [ ] **Observability → Cases** (or workflow-driven case) is usable for ops triage
- [ ] Optional: **Agent Builder** context agent behavior documented for this scenario

## Acceptance criteria

<!-- Bullet list of “done” for this issue. -->

## Links and references

- Cloud path workflows: `elastic-agent-builder-a2a-cloud-path/kibana-workflows/yaml/`
- Dashboard script: `elastic-agent-builder-a2a-cloud-path/scripts/09-lab-dashboards-api.sh`
