#!/usr/bin/env python3
"""Lab Chaos Console — injects synthetic workshop telemetry; does not execute planted vulns."""
from __future__ import annotations

import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

HERE = Path(__file__).resolve().parent
STATIC = HERE / "static" / "index.html"
WORKSHOP_ROOT = Path(os.environ.get("ELASTIC_WORKSHOP_ROOT", "/root/elastic-workshop"))
SIM = WORKSHOP_ROOT / "scripts" / "simulate-cross-domain-load.sh"

KINDS = {
    "/chaos/healthy": "healthy",
    "/chaos/credential_stuffing": "credential_stuffing",
    "/chaos/sqli": "sqli",
    "/chaos/debug_leak": "debug_leak",
}


def env_file() -> Path:
    override = os.environ.get("ELASTIC_WORKSHOP_ENV_FILE")
    if override:
        return Path(override)
    local = WORKSHOP_ROOT / ".env"
    if local.is_file():
        return local
    # Cloud-path sibling when running from a git checkout
    sibling = HERE.parents[2] / "elastic-agent-builder-a2a-cloud-path" / "state" / "workshop.env"
    return sibling


def run_sim(kind: str) -> tuple[int, str]:
    ef = env_file()
    if not ef.is_file():
        return 503, f"Missing credentials file: {ef}\nCopy env.template to .env (Instruqt) or use cloud-path state/workshop.env.\n"
    if not SIM.is_file():
        return 500, f"Missing simulator: {SIM}\n"
    env = os.environ.copy()
    env["ELASTIC_WORKSHOP_ROOT"] = str(WORKSHOP_ROOT)
    env["ELASTIC_WORKSHOP_ENV_FILE"] = str(ef)
    env["SIMULATE_ATTACK_KIND"] = kind
    env["SIMULATE_HOST"] = env.get("SIMULATE_HOST", "prod-db-01")
    env["SIMULATE_SERVICE"] = env.get("SIMULATE_SERVICE", "claims-portal")
    if kind == "healthy":
        env["SIMULATE_ROUNDS"] = env.get("CHAOS_HEALTHY_ROUNDS", "2")
        env["SIMULATE_BURST_SIZE"] = env.get("CHAOS_HEALTHY_BURST", "4")
        env["SIMULATE_SLEEP_SEC"] = "0"
    else:
        env["SIMULATE_ROUNDS"] = env.get("CHAOS_ATTACK_ROUNDS", "3")
        env["SIMULATE_BURST_SIZE"] = env.get("CHAOS_ATTACK_BURST", "10")
        env["SIMULATE_SLEEP_SEC"] = "0"
    proc = subprocess.run(
        ["bash", str(SIM)],
        env=env,
        capture_output=True,
        text=True,
        timeout=180,
        check=False,
    )
    out = (proc.stdout or "") + (proc.stderr or "")
    if proc.returncode != 0:
        return 500, f"Simulator exit {proc.returncode}\n{out}"
    return 200, f"Injected kind={kind} host=prod-db-01 service=claims-portal\n\n{out}"


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _send(self, code: int, body: bytes, content_type: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path in ("/", "/index.html"):
            html = STATIC.read_bytes()
            self._send(200, html, "text/html; charset=utf-8")
            return
        if path == "/health":
            self._send(200, b"ok\n", "text/plain; charset=utf-8")
            return
        self._send(404, b"not found\n", "text/plain; charset=utf-8")

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        kind = KINDS.get(path)
        if not kind:
            self._send(404, b"unknown chaos kind\n", "text/plain; charset=utf-8")
            return
        code, text = run_sim(kind)
        self._send(code, text.encode("utf-8"), "text/plain; charset=utf-8")


def main() -> None:
    port = int(os.environ.get("CHAOS_UI_PORT", "8082"))
    host = os.environ.get("CHAOS_UI_HOST", "0.0.0.0")
    httpd = ThreadingHTTPServer((host, port), Handler)
    print(f"Chaos Console on http://{host}:{port} (env file {env_file()})", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
