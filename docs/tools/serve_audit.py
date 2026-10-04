#!/usr/bin/env python3
"""Local-only audit server: serves this repository and records diagnostic JSON."""
import json
import re
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/audits/2026-10-04/followup"

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_POST(self):
        if self.path != "/audit-result":
            self.send_error(404)
            return
        size = int(self.headers.get("Content-Length", "0"))
        if not 0 < size < 10_000_000:
            self.send_error(413)
            return
        try:
            result = json.loads(self.rfile.read(size))
            name = result["name"]
            if not re.fullmatch(r"[a-z0-9_-]{1,100}", name):
                raise ValueError("Invalid report name")
        except (ValueError, KeyError, TypeError):
            self.send_error(400)
            return
        OUTPUT.mkdir(parents=True, exist_ok=True)
        temporary = OUTPUT / (name + ".tmp")
        temporary.write_text(json.dumps(result, indent=2) + "\n")
        temporary.replace(OUTPUT / (name + ".json"))
        self.send_response(204)
        self.end_headers()

    def log_message(self, *_args):
        pass

if __name__ == "__main__":
    print("Audit server: http://127.0.0.1:8071", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 8071), Handler).serve_forever()
