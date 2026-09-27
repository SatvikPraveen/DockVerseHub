# Location: research/experiments/fixtures/app/app.py
"""Minimal Flask service used as the constant workload across all experiments.

It deliberately does nothing beyond answering /health so that measured
differences come from the container image, not from the application.
"""

import os
import time

from flask import Flask, jsonify

START = time.time()
app = Flask(__name__)


@app.get("/health")
def health():
    return jsonify(status="ok", uptime_s=round(time.time() - START, 3)), 200


@app.get("/")
def index():
    return jsonify(service="dockversehub-research-fixture"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "5000")))
