#!/usr/bin/env python3
"""Substitute A2A placeholders in workflow YAML before POST/PUT to Kibana.

Env (from 06 after sourcing workshop.env):
  A2A_BOOTSTRAP_JSON — absolute path to state/bootstrap.json (set by 06)

Optional overrides in workshop.env:
  O11Y_AGENT_ENDPOINT — if set, Security workflows POST here with ApiKey O11Y_API_KEY
  O11Y_API_KEY — used only when O11Y_AGENT_ENDPOINT is set (published / custom URL)
  SECURITY_AGENT_ENDPOINT — if set, Observability workflows POST here with SECURITY_* API key
  SECURITY_AGENT_API_KEY or SECURITY_API_KEY — used when SECURITY_AGENT_ENDPOINT is set

Defaults (when overrides are unset and bootstrap.json is available):
  Security → Observability: POST {Observability Kibana}/api/agent_builder/converse with Basic auth
    (project admin from bootstrap). Body uses agent_id a2a-lab-observability-context.
  Observability → Security: POST {Security Kibana}/api/agent_builder/converse with Basic auth.
    Body uses agent_id a2a-lab-security-detection.

Placeholders in YAML:
  __WF_O11Y_AGENT_ENDPOINT__, __WF_O11Y_AUTHORIZATION__
  __WF_SECURITY_AGENT_ENDPOINT__, __WF_SECURITY_AUTHORIZATION__
"""
from __future__ import annotations

import base64
import json
import os
import sys


def read_bootstrap() -> dict | None:
    path = os.environ.get("A2A_BOOTSTRAP_JSON", "").strip()
    if path and os.path.isfile(path):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    return None


def basic_token(user: str, password: str) -> str:
    raw = f"{user}:{password}".encode("utf-8")
    return base64.b64encode(raw).decode("ascii")


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: render-workflow-placeholders.py <src.yaml> <dst.yaml>", file=sys.stderr)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, encoding="utf-8") as f:
        text = f.read()

    boot = read_bootstrap()

    o11y_explicit = os.environ.get("O11Y_AGENT_ENDPOINT", "").strip()
    o11y_key = os.environ.get("O11Y_API_KEY", "").strip()
    if o11y_explicit:
        o11y_url = o11y_explicit
        o11y_auth = f"ApiKey {o11y_key}" if o11y_key else ""
    elif boot:
        kb = boot["observability"]["endpoints"]["kibana"].rstrip("/")
        o11y_url = f"{kb}/api/agent_builder/converse"
        u = boot["observability"]["credentials"]["username"]
        p = boot["observability"]["credentials"]["password"]
        o11y_auth = f"Basic {basic_token(u, p)}"
    else:
        o11y_url = "https://a2a-placeholder.invalid/missing-bootstrap-for-O11y-converse"
        o11y_auth = ""

    sec_explicit = os.environ.get("SECURITY_AGENT_ENDPOINT", "").strip()
    sec_key = (
        os.environ.get("SECURITY_AGENT_API_KEY", "").strip()
        or os.environ.get("SECURITY_API_KEY", "").strip()
    )
    if sec_explicit:
        sec_url = sec_explicit
        sec_auth = f"ApiKey {sec_key}" if sec_key else ""
    elif boot:
        kb = boot["security"]["endpoints"]["kibana"].rstrip("/")
        sec_url = f"{kb}/api/agent_builder/converse"
        u = boot["security"]["credentials"]["username"]
        p = boot["security"]["credentials"]["password"]
        sec_auth = f"Basic {basic_token(u, p)}"
    else:
        sec_url = "https://a2a-placeholder.invalid/missing-bootstrap-for-Security-converse"
        sec_auth = ""

    text = text.replace("__WF_O11Y_AGENT_ENDPOINT__", o11y_url)
    text = text.replace("__WF_O11Y_AUTHORIZATION__", o11y_auth)
    text = text.replace("__WF_SECURITY_AGENT_ENDPOINT__", sec_url)
    text = text.replace("__WF_SECURITY_AUTHORIZATION__", sec_auth)

    # Legacy placeholder from earlier revisions (no-op if absent)
    text = text.replace("__WF_O11Y_API_KEY__", "")
    text = text.replace("__WF_SECURITY_AGENT_API_KEY__", "")

    with open(dst, "w", encoding="utf-8") as f:
        f.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
