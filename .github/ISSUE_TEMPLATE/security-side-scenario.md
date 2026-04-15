---
name: Security-side scenario
about: Track a Security-only lab story — detections, cases, workflows, or synthetic attack narratives (e.g. lateral movement, suspicious code execution).
title: "[Security] "
labels: []
assignees: []
---

## Scenario summary

<!-- One paragraph: what the Security team cares about in this thread. -->

Example angles: **lateral movement**, **suspicious code execution** (scripts, interpreters, LOLBins), **credential abuse**, **C2-like patterns**, **data staging**, or **detection / rule tuning** for the A2A Security project.

## Signals and indices

- **Indices / data streams** involved (e.g. `workshop-synth-endpoint-alerts`, `.elastic-agents-security-a2a-enriched`):
- **Fields or entities** that must appear in alerts or cases (host, user, process, parent process, hash):

## What we want to prove in Kibana

- [ ] Detection or ES query rule behaves as expected
- [ ] **Elastic Security → Cases** (or workflow-driven case) tells the right story
- [ ] Optional: **Agent Builder** enrichment or **A2A** call-out documented for this scenario

## Acceptance criteria

<!-- Bullet list of “done” for this issue. -->

## Links and references

- Cloud path workflows: `elastic-agent-builder-a2a-cloud-path/kibana-workflows/yaml/`
- Scaffolds: `elastic-agent-builder-a2a-workshop/agent-scaffolds/`
