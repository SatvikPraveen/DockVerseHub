# Location: research/harness/docker_ops.py
"""Thin, timed wrappers around the Docker CLI.

The CLI is used instead of the Python SDK so that BuildKit features
(cache mounts, multi-stage pruning) behave exactly as they do for a user
at a terminal, and so the harness has no third-party dependency.

All public functions raise `DockerError` on failure and never swallow
non-zero exit codes; a benchmark that silently records a failed build is
worse than no benchmark at all.
"""

from __future__ import annotations

import http.client
import os
import shutil
import subprocess
import tempfile
import time
import uuid
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path


class DockerError(RuntimeError):
    """Raised when a docker command exits non-zero."""


def _docker(
    args: list[str], timeout: float | None = None, env: Mapping[str, str] | None = None
) -> subprocess.CompletedProcess[str]:
    full_env = dict(os.environ)
    full_env.setdefault("DOCKER_BUILDKIT", "1")
    if env:
        full_env.update(env)
    proc = subprocess.run(
        ["docker", *args],
        capture_output=True,
        text=True,
        timeout=timeout,
        env=full_env,
        check=False,
    )
    if proc.returncode != 0:
        raise DockerError(
            f"docker {' '.join(args[:3])}... failed ({proc.returncode}):\n{proc.stderr[-4000:]}"
        )
    return proc


def daemon_available() -> bool:
    try:
        subprocess.run(["docker", "info"], capture_output=True, timeout=20, check=True)
        return True
    except (OSError, subprocess.SubprocessError):
        return False


@dataclass(frozen=True)
class BuildResult:
    tag: str
    seconds: float
    size_bytes: int
    layer_count: int


def build(
    context: Path,
    dockerfile: Path,
    tag: str,
    no_cache: bool,
    build_args: Mapping[str, str] | None = None,
    timeout: float = 1800.0,
) -> BuildResult:
    """Build an image and return wall-clock build time, size and layer count."""
    args = ["build", "--progress=plain", "-f", str(dockerfile), "-t", tag]
    if no_cache:
        args.append("--no-cache")
    for k, v in (build_args or {}).items():
        args += ["--build-arg", f"{k}={v}"]
    args.append(str(context))
    t0 = time.perf_counter()
    _docker(args, timeout=timeout)
    seconds = time.perf_counter() - t0
    return BuildResult(
        tag=tag, seconds=seconds, size_bytes=image_size(tag), layer_count=layer_count(tag)
    )


def image_size(tag: str) -> int:
    out = _docker(["image", "inspect", "--format", "{{.Size}}", tag]).stdout.strip()
    return int(out)


def layer_count(tag: str) -> int:
    """Count non-empty filesystem layers (RootFS diff IDs)."""
    out = _docker(["image", "inspect", "--format", "{{len .RootFS.Layers}}", tag]).stdout.strip()
    return int(out)


def remove_image(tag: str) -> None:
    subprocess.run(["docker", "rmi", "-f", tag], capture_output=True, check=False)


def prune_build_cache() -> None:
    """Drop the BuildKit cache so `no_cache` measurements are truly cold."""
    subprocess.run(["docker", "builder", "prune", "-af"], capture_output=True, check=False)


def _host_port(container: str, container_port: int) -> int:
    out = _docker(["port", container, str(container_port)]).stdout.strip().splitlines()
    # e.g. "0.0.0.0:55001" or "[::]:55001"
    return int(out[0].rsplit(":", 1)[1])


def _http_ok(port: int, path: str, timeout: float = 0.5) -> bool:
    try:
        conn = http.client.HTTPConnection("127.0.0.1", port, timeout=timeout)
        conn.request("GET", path)
        ok = 200 <= conn.getresponse().status < 300
        conn.close()
        return ok
    except OSError:
        return False


def time_to_ready(
    tag: str,
    container_port: int = 5000,
    health_path: str = "/health",
    timeout: float = 60.0,
    poll_interval: float = 0.02,
    env: Mapping[str, str] | None = None,
) -> float:
    """Seconds from `docker run` invocation until the health endpoint answers 2xx.

    This is the user-perceived cold start: image already present, container
    created, started, application initialised, first successful request.
    """
    name = f"dvh-bench-{uuid.uuid4().hex[:12]}"
    args = ["run", "-d", "--rm", "--name", name, "-p", f"127.0.0.1::{container_port}"]
    for k, v in (env or {}).items():
        args += ["-e", f"{k}={v}"]
    args.append(tag)
    t0 = time.perf_counter()
    try:
        _docker(args)
        port = None
        deadline = t0 + timeout
        while time.perf_counter() < deadline:
            if port is None:
                try:
                    port = _host_port(name, container_port)
                except (DockerError, IndexError, ValueError):
                    time.sleep(poll_interval)
                    continue
            if _http_ok(port, health_path):
                return time.perf_counter() - t0
            time.sleep(poll_interval)
        logs = subprocess.run(["docker", "logs", name], capture_output=True, text=True, check=False)
        raise DockerError(
            f"{tag} not ready within {timeout}s. Logs:\n{logs.stdout[-2000:]}{logs.stderr[-2000:]}"
        )
    finally:
        subprocess.run(["docker", "rm", "-f", name], capture_output=True, check=False)


def run_trivial(tag: str, command: list[str], timeout: float = 120.0) -> float:
    """Seconds for `docker run --rm <tag> <command>` to complete (create+start+exit+teardown)."""
    t0 = time.perf_counter()
    _docker(["run", "--rm", tag, *command], timeout=timeout)
    return time.perf_counter() - t0


class ScratchContext:
    """A disposable copy of a build context that experiments may mutate.

    Used by cache-probe experiments: build once to warm the cache, mutate a
    file, rebuild, and time only the second build.
    """

    def __init__(self, source: Path):
        self.source = source
        self._tmp = tempfile.mkdtemp(prefix="dvh-ctx-")
        self.path = Path(self._tmp) / "ctx"
        shutil.copytree(source, self.path)

    def mutate(self, relative_file: str, nonce: str | None = None) -> None:
        target = self.path / relative_file
        marker = nonce or uuid.uuid4().hex
        with target.open("a", encoding="utf-8") as fh:
            fh.write(f"\n# cache-probe {marker}\n")

    def cleanup(self) -> None:
        shutil.rmtree(self._tmp, ignore_errors=True)

    def __enter__(self) -> ScratchContext:
        return self

    def __exit__(self, *exc: object) -> None:
        self.cleanup()
