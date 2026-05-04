#!/usr/bin/env bash
# Push every workflow under kibana-workflows/yaml/ to Security and Observability Kibana.
#
# Implements the same PUT/POST /api/workflows/workflow flow as 06-kibana-workflows-lab.sh,
# documented alongside Elastic Agent Skills:
#   - kibana-alerting-rules (workflow rule actions, kbn-xsrf)
#   - kibana-connectors/references/workflows.md (alert YAML, preview notes)
#
# Usage: from elastic-agent-builder-a2a-cloud-path, ensure state/bootstrap.json exists
# (after 01-provision) or set A2A_SEC_KIBANA_* / A2A_O11Y_KIBANA_* overrides, then:
#   ./scripts/push-kibana-workflows.sh
#
# Pass-through: any arguments are forwarded to 06-kibana-workflows-lab.sh (none today).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/06-kibana-workflows-lab.sh" "$@"
