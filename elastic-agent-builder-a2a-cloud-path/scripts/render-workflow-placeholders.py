#!/usr/bin/env python3
"""Substitute A2A placeholders in workflow YAML before POST/PUT to Kibana.

Env:
  A2A_BOOTSTRAP_JSON — path to state/bootstrap.json (required for converse defaults and Basic auth)

workshop.env (sourced by 06 before this runs) should normally include (written by 02 or appended by 06):
  O11Y_AGENT_ENDPOINT — default {Observability Kibana}/api/agent_builder/converse
  SECURITY_AGENT_ENDPOINT — default {Security Kibana}/api/agent_builder/converse

Auth rules:
  * URL path contains /api/agent_builder/converse → Basic auth for that project's Kibana admin (from bootstrap)
  * Any other URL → ApiKey from O11Y_API_KEY or SECURITY_AGENT_API_KEY / SECURITY_API_KEY

Placeholders: __WF_O11Y_AGENT_ENDPOINT__, __WF_O11Y_AUTHORIZATION__, __WF_SECURITY_*__
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


def is_converse_url(url: str) -> bool:
    return "/api/agent_builder/converse" in url


def o11y_pair(boot: dict | None, explicit: str, api_key: str) -> tuple[str, str]:
    if explicit:
        url = explicit
        if is_converse_url(url):
            if not boot:
                raise ValueError("O11Y_AGENT_ENDPOINT is converse URL but A2A_BOOTSTRAP_JSON bootstrap is missing")
            u = boot["observability"]["credentials"]["username"]
            p = boot["observability"]["credentials"]["password"]
            auth = f"Basic {basic_token(u, p)}"
        else:
            auth = f"ApiKey {api_key}" if api_key else ""
        return url, auth
    if boot:
        kb = boot["observability"]["endpoints"]["kibana"].rstrip("/")
        url = f"{kb}/api/agent_builder/converse"
        u = boot["observability"]["credentials"]["username"]
        p = boot["observability"]["credentials"]["password"]
        return url, f"Basic {basic_token(u, p)}"
    raise ValueError("Cannot resolve Observability A2A URL (set O11Y_AGENT_ENDPOINT or fix bootstrap.json)")


def security_pair(boot: dict | None, explicit: str, api_key: str) -> tuple[str, str]:
    if explicit:
        url = explicit
        if is_converse_url(url):
            if not boot:
                raise ValueError("SECURITY_AGENT_ENDPOINT is converse URL but bootstrap is missing")
            u = boot["security"]["credentials"]["username"]
            p = boot["security"]["credentials"]["password"]
            auth = f"Basic {basic_token(u, p)}"
        else:
            auth = f"ApiKey {api_key}" if api_key else ""
        return url, auth
    if boot:
        kb = boot["security"]["endpoints"]["kibana"].rstrip("/")
        url = f"{kb}/api/agent_builder/converse"
        u = boot["security"]["credentials"]["username"]
        p = boot["security"]["credentials"]["password"]
        return url, f"Basic {basic_token(u, p)}"
    raise ValueError("Cannot resolve Security A2A URL (set SECURITY_AGENT_ENDPOINT or fix bootstrap.json)")


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: render-workflow-placeholders.py <src.yaml> <dst.yaml>", file=sys.stderr)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, encoding="utf-8") as f:
        text = f.read()

    boot = read_bootstrap()

    try:
        o11y_url, o11y_auth = o11y_pair(
            boot,
            os.environ.get("O11Y_AGENT_ENDPOINT", "").strip(),
            os.environ.get("O11Y_API_KEY", "").strip(),
        )
        sec_key = (
            os.environ.get("SECURITY_AGENT_API_KEY", "").strip()
            or os.environ.get("SECURITY_API_KEY", "").strip()
        )
        sec_url, sec_auth = security_pair(
            boot,
            os.environ.get("SECURITY_AGENT_ENDPOINT", "").strip(),
            sec_key,
        )
    except ValueError as e:
        print(f"render-workflow-placeholders: {e}", file=sys.stderr)
        return 1

    if not o11y_auth:
        print("render-workflow-placeholders: empty O11y Authorization (set O11Y_API_KEY for non-converse URLs)", file=sys.stderr)
        return 1
    if not sec_auth:
        print(
            "render-workflow-placeholders: empty Security Authorization (set SECURITY_API_KEY for non-converse URLs)",
            file=sys.stderr,
        )
        return 1

    text = text.replace("__WF_O11Y_AGENT_ENDPOINT__", o11y_url)
    text = text.replace("__WF_O11Y_AUTHORIZATION__", o11y_auth)
    text = text.replace("__WF_SECURITY_AGENT_ENDPOINT__", sec_url)
    text = text.replace("__WF_SECURITY_AUTHORIZATION__", sec_auth)
    text = text.replace("__WF_O11Y_API_KEY__", "")
    text = text.replace("__WF_SECURITY_AGENT_API_KEY__", "")

    with open(dst, "w", encoding="utf-8") as f:
        f.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
