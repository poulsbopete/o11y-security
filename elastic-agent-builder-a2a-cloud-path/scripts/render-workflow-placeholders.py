#!/usr/bin/env python3
"""Substitute A2A placeholders in workflow YAML before POST/PUT to Kibana.

Reads env (exported by 06-kibana-workflows-lab.sh after sourcing workshop.env):
  O11Y_AGENT_ENDPOINT, O11Y_API_KEY — Security workflows POST to Observability agent
  SECURITY_AGENT_ENDPOINT, SECURITY_AGENT_API_KEY (else SECURITY_API_KEY) — O11y workflows POST to Security agent

Placeholders in YAML:
  __WF_O11Y_AGENT_ENDPOINT__, __WF_O11Y_API_KEY__
  __WF_SECURITY_AGENT_ENDPOINT__, __WF_SECURITY_AGENT_API_KEY__
"""
from __future__ import annotations

import os
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: render-workflow-placeholders.py <src.yaml> <dst.yaml>", file=sys.stderr)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, encoding="utf-8") as f:
        text = f.read()

    o11y_url = os.environ.get("O11Y_AGENT_ENDPOINT", "").strip()
    o11y_key = os.environ.get("O11Y_API_KEY", "").strip()
    sec_url = os.environ.get("SECURITY_AGENT_ENDPOINT", "").strip()
    sec_key = (
        os.environ.get("SECURITY_AGENT_API_KEY", "").strip()
        or os.environ.get("SECURITY_API_KEY", "").strip()
    )

    text = text.replace(
        "__WF_O11Y_AGENT_ENDPOINT__",
        o11y_url or "https://a2a-placeholder.invalid/configure-O11Y_AGENT_ENDPOINT-in-workshop-env",
    )
    if o11y_key:
        text = text.replace("__WF_O11Y_API_KEY__", o11y_key)
    else:
        text = text.replace('        Authorization: "ApiKey __WF_O11Y_API_KEY__"\n', "")

    text = text.replace(
        "__WF_SECURITY_AGENT_ENDPOINT__",
        sec_url or "https://a2a-placeholder.invalid/configure-SECURITY_AGENT_ENDPOINT-in-workshop-env",
    )
    if sec_key:
        text = text.replace("__WF_SECURITY_AGENT_API_KEY__", sec_key)
    else:
        text = text.replace('        Authorization: "ApiKey __WF_SECURITY_AGENT_API_KEY__"\n', "")

    with open(dst, "w", encoding="utf-8") as f:
        f.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
