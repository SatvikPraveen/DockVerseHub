# File Location: concepts/06_security/app.py
"""Tiny HTTP service used by Dockerfile.rootless and Dockerfile.hardened.

It reports the identity it runs as and whether its own code directory is
writable, so the security properties of the image can be verified from a
browser or curl instead of by trusting the Dockerfile comments.
"""

import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer


def _writable(path: str) -> bool:
    return os.access(path, os.W_OK)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802 (http.server API)
        if self.path == "/health":
            body = {"status": "ok"}
        else:
            body = {
                "uid": os.getuid(),
                "gid": os.getgid(),
                "is_root": os.getuid() == 0,
                "app_dir_writable": _writable("/app"),
                "data_dir_writable": _writable("/data"),
                "cwd": os.getcwd(),
            }
        payload = json.dumps(body).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):  # keep container logs quiet
        return


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()
