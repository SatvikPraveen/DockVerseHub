# Location: research/harness/runner.py
"""Experiment runner: turns a declarative experiment file into raw measurements.

Protocol (see research/METHODOLOGY.md):

1. The environment is snapshotted before any measurement.
2. `warmup` un-recorded rounds pull base images and populate registries.
3. `repetitions` recorded rounds follow. Within each round every variant
   is measured exactly once; the order of variants is re-shuffled per round
   from a seeded RNG (block-randomised, interleaved design) so that slow
   drift on the host (thermal throttling, background jobs, disk cache
   state) is spread evenly across variants instead of biasing one of them.
4. Each trial is appended to `raw.jsonl` immediately, so an interrupted
   run still leaves analysable data.

Two procedures are supported:

* `build`        - cold (`--no-cache`) build; records build time, image size,
                   layer count and, if `readiness` is configured, cold start.
* `cache_probe`  - warm build, mutate one file, timed rebuild; records the
                   incremental rebuild time. This isolates layer-cache
                   effectiveness from raw build speed.
"""

from __future__ import annotations

import json
import random
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Protocol

from . import docker_ops, environment


class Ops(Protocol):
    """Subset of docker_ops used by the runner (injectable for tests)."""

    def build(
        self,
        context: Path,
        dockerfile: Path,
        tag: str,
        no_cache: bool,
        build_args: dict[str, str] | None = None,
        timeout: float = 1800.0,
    ) -> docker_ops.BuildResult: ...
    def time_to_ready(
        self,
        tag: str,
        container_port: int = 5000,
        health_path: str = "/health",
        timeout: float = 60.0,
        poll_interval: float = 0.02,
        env: dict[str, str] | None = None,
    ) -> float: ...
    def remove_image(self, tag: str) -> None: ...
    def prune_build_cache(self) -> None: ...


@dataclass(frozen=True)
class Variant:
    name: str
    dockerfile: str
    context: str
    build_args: dict[str, str] = field(default_factory=dict)
    description: str = ""


@dataclass(frozen=True)
class Experiment:
    id: str
    title: str
    hypothesis: str
    procedure: str  # "build" | "cache_probe"
    variants: list[Variant]
    baseline: str
    repetitions: int = 5
    warmup: int = 1
    seed: int = 42
    readiness: dict[str, Any] | None = None  # {"port":5000,"path":"/health","timeout":60}
    cache_probe: dict[str, Any] | None = None  # {"mutate_file":"app.py"}
    prune_between_trials: bool = False
    tags: list[str] = field(default_factory=list)
    notes: str = ""

    @property
    def variant_names(self) -> list[str]:
        return [v.name for v in self.variants]

    @staticmethod
    def load(path: Path) -> Experiment:
        data = json.loads(path.read_text(encoding="utf-8"))
        design = data.get("design", {})
        variants = [Variant(**v) for v in data["variants"]]
        names = [v.name for v in variants]
        if len(set(names)) != len(names):
            raise ValueError(f"{path}: duplicate variant names")
        if data["baseline"] not in names:
            raise ValueError(f"{path}: baseline {data['baseline']!r} is not a variant")
        if data["procedure"] not in {"build", "cache_probe"}:
            raise ValueError(f"{path}: unknown procedure {data['procedure']!r}")
        if data["procedure"] == "cache_probe" and not data.get("cache_probe", {}).get(
            "mutate_file"
        ):
            raise ValueError(f"{path}: cache_probe procedure needs cache_probe.mutate_file")
        return Experiment(
            id=data["id"],
            title=data["title"],
            hypothesis=data["hypothesis"],
            procedure=data["procedure"],
            variants=variants,
            baseline=data["baseline"],
            repetitions=int(design.get("repetitions", 5)),
            warmup=int(design.get("warmup", 1)),
            seed=int(design.get("seed", 42)),
            readiness=data.get("readiness"),
            cache_probe=data.get("cache_probe"),
            prune_between_trials=bool(design.get("prune_between_trials", False)),
            tags=list(data.get("tags", [])),
            notes=data.get("notes", ""),
        )


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


class Runner:
    def __init__(
        self,
        experiment: Experiment,
        experiments_dir: Path,
        results_dir: Path,
        ops: Ops | None = None,
        repetitions: int | None = None,
        warmup: int | None = None,
        log: Callable[[str], None] = print,
        run_id: str | None = None,
    ):
        self.exp = experiment
        self.experiments_dir = experiments_dir
        self.ops: Ops = ops or docker_ops  # type: ignore[assignment]
        self.repetitions = repetitions if repetitions is not None else experiment.repetitions
        self.warmup = warmup if warmup is not None else experiment.warmup
        self.log = log
        self.run_id = run_id or datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        self.out_dir = results_dir / experiment.id / self.run_id
        self.raw_path = self.out_dir / "raw.jsonl"

    # -- paths ---------------------------------------------------------------
    def _resolve(self, rel: str) -> Path:
        return (self.experiments_dir / rel).resolve()

    def _tag(self, variant: Variant) -> str:
        return f"dvh-research/{self.exp.id}:{variant.name}".lower()

    # -- trials --------------------------------------------------------------
    def _trial_build(self, variant: Variant, round_no: int) -> dict[str, Any]:
        if self.exp.prune_between_trials:
            self.ops.prune_build_cache()
        tag = self._tag(variant)
        res = self.ops.build(
            self._resolve(variant.context),
            self._resolve(variant.dockerfile),
            tag,
            no_cache=True,
            build_args=variant.build_args,
        )
        metrics: dict[str, float] = {
            "build_time_s": res.seconds,
            "image_size_mb": res.size_bytes / 1_000_000.0,
            "layer_count": float(res.layer_count),
        }
        if self.exp.readiness:
            r = self.exp.readiness
            metrics["time_to_ready_s"] = self.ops.time_to_ready(
                tag,
                container_port=int(r.get("port", 5000)),
                health_path=str(r.get("path", "/health")),
                timeout=float(r.get("timeout", 60)),
                env=r.get("env"),
            )
        return metrics

    def _trial_cache_probe(self, variant: Variant, round_no: int) -> dict[str, Any]:
        assert self.exp.cache_probe is not None
        tag = self._tag(variant)
        with docker_ops.ScratchContext(self._resolve(variant.context)) as ctx:
            dockerfile = self._resolve(variant.dockerfile)
            # Dockerfile may live outside the context; copy it in so relative paths hold.
            df_local = ctx.path / dockerfile.name
            if not df_local.exists():
                df_local.write_bytes(dockerfile.read_bytes())
            warm = self.ops.build(
                ctx.path, df_local, tag, no_cache=False, build_args=variant.build_args
            )
            ctx.mutate(self.exp.cache_probe["mutate_file"], nonce=f"r{round_no}-{time.time_ns()}")
            incremental = self.ops.build(
                ctx.path, df_local, tag, no_cache=False, build_args=variant.build_args
            )
        return {
            "warm_build_s": warm.seconds,
            "incremental_rebuild_s": incremental.seconds,
            "image_size_mb": incremental.size_bytes / 1_000_000.0,
            "layer_count": float(incremental.layer_count),
        }

    def _trial(self, variant: Variant, round_no: int) -> dict[str, Any]:
        if self.exp.procedure == "build":
            return self._trial_build(variant, round_no)
        return self._trial_cache_probe(variant, round_no)

    # -- orchestration -------------------------------------------------------
    def run(self) -> Path:
        self.out_dir.mkdir(parents=True, exist_ok=True)
        (self.out_dir / "experiment.json").write_text(
            json.dumps(
                {
                    "id": self.exp.id,
                    "title": self.exp.title,
                    "hypothesis": self.exp.hypothesis,
                    "procedure": self.exp.procedure,
                    "baseline": self.exp.baseline,
                    "variants": [v.__dict__ for v in self.exp.variants],
                    "design": {
                        "repetitions": self.repetitions,
                        "warmup": self.warmup,
                        "seed": self.exp.seed,
                        "order": "block-randomised",
                    },
                    "readiness": self.exp.readiness,
                    "cache_probe": self.exp.cache_probe,
                    "tags": self.exp.tags,
                    "notes": self.exp.notes,
                },
                indent=2,
            ),
            encoding="utf-8",
        )
        (self.out_dir / "environment.json").write_text(
            json.dumps(environment.capture(self.experiments_dir), indent=2), encoding="utf-8"
        )

        rng = random.Random(self.exp.seed)
        total_rounds = self.warmup + self.repetitions
        self.log(
            f"[{self.exp.id}] {len(self.exp.variants)} variants x {self.repetitions} reps (+{self.warmup} warmup) -> {self.out_dir}"
        )
        with self.raw_path.open("a", encoding="utf-8") as raw:
            for round_no in range(total_rounds):
                recorded = round_no >= self.warmup
                order = list(self.exp.variants)
                rng.shuffle(order)
                for position, variant in enumerate(order):
                    label = "rep" if recorded else "warmup"
                    self.log(
                        f"  round {round_no + 1}/{total_rounds} ({label}) variant={variant.name}"
                    )
                    started = _now()
                    t0 = time.perf_counter()
                    try:
                        metrics = self._trial(variant, round_no)
                        status, error = "ok", None
                    except Exception as exc:  # recorded, never swallowed silently
                        metrics, status, error = {}, "error", f"{type(exc).__name__}: {exc}"[:2000]
                        self.log(f"    ! {error.splitlines()[0]}")
                    record = {
                        "experiment": self.exp.id,
                        "run_id": self.run_id,
                        "round": round_no,
                        "position_in_round": position,
                        "recorded": recorded,
                        "variant": variant.name,
                        "status": status,
                        "error": error,
                        "started_at": started,
                        "elapsed_s": time.perf_counter() - t0,
                        "metrics": metrics,
                    }
                    raw.write(json.dumps(record) + "\n")
                    raw.flush()
        for variant in self.exp.variants:
            self.ops.remove_image(self._tag(variant))
        return self.out_dir


def load_raw(path: Path) -> list[dict[str, Any]]:
    with path.open(encoding="utf-8") as fh:
        return [json.loads(line) for line in fh if line.strip()]
