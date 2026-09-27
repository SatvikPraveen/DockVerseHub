# Location: research/harness/environment.py
"""Capture the execution environment so every result is self-describing.

A benchmark number without its environment is not reproducible. Every run
stores this snapshot next to the raw measurements.
"""

from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
from datetime import datetime, timezone
from typing import Any


def _run(cmd: list[str]) -> str | None:
    try:
        return (
            subprocess.run(
                cmd, capture_output=True, text=True, timeout=30, check=False
            ).stdout.strip()
            or None
        )
    except (OSError, subprocess.SubprocessError):
        return None


def _docker_info() -> dict[str, Any]:
    raw = _run(["docker", "info", "--format", "{{json .}}"])
    if not raw:
        return {}
    try:
        info = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    keys = [
        "ServerVersion",
        "Driver",
        "CgroupDriver",
        "CgroupVersion",
        "KernelVersion",
        "OperatingSystem",
        "OSType",
        "Architecture",
        "NCPU",
        "MemTotal",
        "DefaultRuntime",
    ]
    return {k: info.get(k) for k in keys if k in info}


def capture(repo_root: str | os.PathLike[str] | None = None) -> dict[str, Any]:
    """Return a JSON-serialisable snapshot of the host, Docker and git state."""
    git_commit = _run(["git", "-C", str(repo_root or "."), "rev-parse", "HEAD"])
    git_dirty = _run(["git", "-C", str(repo_root or "."), "status", "--porcelain"])
    return {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "host": {
            "platform": platform.platform(),
            "machine": platform.machine(),
            "processor": platform.processor() or None,
            "python": platform.python_version(),
            "cpu_count": os.cpu_count(),
        },
        "docker": {
            "client_version": _run(["docker", "version", "--format", "{{.Client.Version}}"]),
            "buildx_version": _run(["docker", "buildx", "version"]),
            "compose_version": _run(["docker", "compose", "version", "--short"]),
            "buildkit_enabled": os.environ.get("DOCKER_BUILDKIT", "1") != "0",
            "binary": shutil.which("docker"),
            **_docker_info(),
        },
        "git": {
            "commit": git_commit,
            "dirty": bool(git_dirty),
        },
        "env": {
            k: v
            for k, v in os.environ.items()
            if k.startswith("DOCKER_")
            or k in {"CI", "GITHUB_ACTIONS", "GITHUB_RUN_ID", "RUNNER_OS"}
        },
    }
