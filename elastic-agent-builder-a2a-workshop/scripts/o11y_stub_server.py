#!/usr/bin/env python3
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length", "0") or 0)
        if length:
            self.rfile.read(length)
        sample = {
            "host": "prod-db-01",
            "time_range": "1m",
            "metrics": {"cpu_percent": 85, "memory_percent": 72, "disk_io_read_mb_sec": 450},
            "traces": {
                "error_rate_percent": 12,
                "latency_p95_ms": 2400,
                "error_rate_spike_detected": True,
            },
            "anomaly_detected": True,
            "context_summary": "Synthetic stub from Instruqt solve script (replace with real Agent Builder endpoint in production workshops).",
        }
        data = json.dumps(sample).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt: str, *args: object) -> None:  # noqa: D102
        return


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 18080), Handler).serve_forever()
