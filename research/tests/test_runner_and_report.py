# Location: research/tests/test_runner_and_report.py
"""Runner and report tests with a fake Docker backend (no daemon required)."""

import json
from pathlib import Path

import pytest

from research.harness import report
from research.harness.docker_ops import BuildResult
from research.harness.runner import Experiment, Runner, load_raw

RESEARCH_DIR = Path(__file__).resolve().parent.parent
EXPERIMENTS_DIR = RESEARCH_DIR / "experiments"


class FakeOps:
    """Deterministic stand-in for docker_ops with per-variant characteristics."""

    def __init__(self, profile: dict[str, dict[str, float]], fail_variant: str | None = None):
        self.profile = profile
        self.fail_variant = fail_variant
        self.calls: list[tuple] = []
        self.removed: list[str] = []
        self.pruned = 0

    def build(self, context, dockerfile, tag, no_cache, build_args=None, timeout=1800.0):
        variant = tag.rsplit(":", 1)[1]
        self.calls.append(("build", variant, no_cache))
        if variant == self.fail_variant:
            raise RuntimeError("simulated build failure")
        p = self.profile[variant]
        return BuildResult(
            tag=tag,
            seconds=p["build"],
            size_bytes=int(p["size"] * 1_000_000),
            layer_count=int(p["layers"]),
        )

    def time_to_ready(
        self,
        tag,
        container_port=5000,
        health_path="/health",
        timeout=60.0,
        poll_interval=0.02,
        env=None,
    ):
        variant = tag.rsplit(":", 1)[1]
        self.calls.append(("ready", variant))
        return self.profile[variant]["ready"]

    def remove_image(self, tag):
        self.removed.append(tag)

    def prune_build_cache(self):
        self.pruned += 1


def _exp(tmp_path: Path, **overrides) -> Path:
    data = {
        "id": "expT_fake",
        "title": "Fake experiment",
        "hypothesis": "B is faster than A.",
        "procedure": "build",
        "baseline": "a",
        "design": {"repetitions": 3, "warmup": 1, "seed": 1},
        "readiness": {"port": 5000, "path": "/health"},
        "variants": [
            {
                "name": "a",
                "dockerfile": "fixtures/base-images/Dockerfile.full",
                "context": "fixtures/app",
            },
            {
                "name": "b",
                "dockerfile": "fixtures/base-images/Dockerfile.slim",
                "context": "fixtures/app",
            },
        ],
    }
    data.update(overrides)
    p = tmp_path / "expT_fake.json"
    p.write_text(json.dumps(data))
    return p


def test_experiment_load_validates(tmp_path):
    e = Experiment.load(_exp(tmp_path))
    assert e.variant_names == ["a", "b"]
    with pytest.raises(ValueError):
        Experiment.load(_exp(tmp_path, baseline="zzz"))
    with pytest.raises(ValueError):
        Experiment.load(_exp(tmp_path, procedure="teleport"))
    with pytest.raises(ValueError):
        Experiment.load(_exp(tmp_path, procedure="cache_probe"))
    with pytest.raises(ValueError):
        Experiment.load(
            _exp(
                tmp_path,
                variants=[
                    {"name": "a", "dockerfile": "x", "context": "y"},
                    {"name": "a", "dockerfile": "x", "context": "y"},
                ],
            )
        )


def test_shipped_experiments_load_and_reference_existing_fixtures():
    files = sorted(EXPERIMENTS_DIR.glob("exp*.json"))
    assert len(files) >= 4
    for f in files:
        e = Experiment.load(f)
        assert e.id == f.stem
        for v in e.variants:
            assert (EXPERIMENTS_DIR / v.dockerfile).is_file(), v.dockerfile
            assert (EXPERIMENTS_DIR / v.context).is_dir(), v.context


def test_runner_block_randomises_and_records(tmp_path):
    profile = {
        "a": {"build": 10.0, "size": 900.0, "layers": 6, "ready": 1.0},
        "b": {"build": 6.0, "size": 150.0, "layers": 6, "ready": 0.5},
    }
    ops = FakeOps(profile)
    exp = Experiment.load(_exp(tmp_path))
    out = Runner(
        exp, EXPERIMENTS_DIR, tmp_path / "results", ops=ops, log=lambda s: None, run_id="t1"
    ).run()

    raw = load_raw(out / "raw.jsonl")
    assert len(raw) == (1 + 3) * 2  # (warmup + reps) * variants
    assert sum(1 for r in raw if r["recorded"]) == 6
    assert all(r["status"] == "ok" for r in raw)
    assert all(r["metrics"]["time_to_ready_s"] > 0 for r in raw)
    # every round contains each variant exactly once
    for rnd in range(4):
        assert sorted(r["variant"] for r in raw if r["round"] == rnd) == ["a", "b"]
    # order is not constant across rounds (seeded shuffle)
    orders = [
        "".join(
            r["variant"]
            for r in sorted(raw, key=lambda r: r["position_in_round"])
            if r["round"] == k
        )
        for k in range(4)
    ]
    assert len(set(orders)) > 1
    assert (out / "experiment.json").exists() and (out / "environment.json").exists()
    assert len(ops.removed) == 2


def test_runner_records_failures_without_aborting(tmp_path):
    profile = {
        "a": {"build": 1, "size": 1, "layers": 1, "ready": 1},
        "b": {"build": 1, "size": 1, "layers": 1, "ready": 1},
    }
    ops = FakeOps(profile, fail_variant="b")
    exp = Experiment.load(_exp(tmp_path, design={"repetitions": 2, "warmup": 0, "seed": 3}))
    out = Runner(exp, EXPERIMENTS_DIR, tmp_path / "results", ops=ops, log=lambda s: None).run()
    raw = load_raw(out / "raw.jsonl")
    failed = [r for r in raw if r["status"] == "error"]
    assert len(failed) == 2 and all(r["variant"] == "b" for r in failed)
    assert "simulated build failure" in failed[0]["error"]
    summary = report.write_report(out)
    assert summary["trials_failed"] == 2
    assert "b" not in summary["metrics"]["build_time_s"]["variants"]
    assert "## Failed trials" in (out / "report.md").read_text()


def test_prune_between_trials_calls_ops(tmp_path):
    profile = {
        "a": {"build": 1, "size": 1, "layers": 1, "ready": 1},
        "b": {"build": 1, "size": 1, "layers": 1, "ready": 1},
    }
    ops = FakeOps(profile)
    exp = Experiment.load(
        _exp(
            tmp_path,
            design={"repetitions": 1, "warmup": 0, "prune_between_trials": True},
            readiness=None,
        )
    )
    Runner(exp, EXPERIMENTS_DIR, tmp_path / "results", ops=ops, log=lambda s: None).run()
    assert ops.pruned == 2
    assert not any(c[0] == "ready" for c in ops.calls)


def test_report_statistics_and_markdown(tmp_path):
    profile = {
        "a": {"build": 10.0, "size": 900.0, "layers": 6, "ready": 1.0},
        "b": {"build": 6.0, "size": 150.0, "layers": 6, "ready": 0.5},
    }
    ops = FakeOps(profile)
    exp = Experiment.load(_exp(tmp_path, design={"repetitions": 4, "warmup": 0, "seed": 5}))
    out = Runner(exp, EXPERIMENTS_DIR, tmp_path / "results", ops=ops, log=lambda s: None).run()
    summary = report.write_report(out)

    size = summary["metrics"]["image_size_mb"]
    assert size["variants"]["a"]["mean"] == pytest.approx(900.0)
    assert size["variants"]["b"]["mean"] == pytest.approx(150.0)
    cmp_b = size["comparisons"]["b"]
    assert cmp_b["delta_pct"] == pytest.approx(-83.333, abs=1e-2)
    assert cmp_b["cliffs_delta"] == -1.0
    # identical layer counts -> zero effect, p = 1
    assert summary["metrics"]["layer_count"]["comparisons"]["b"]["welch_p"] == 1.0

    md = (out / "report.md").read_text()
    assert "# Fake experiment" in md
    assert "`a` (baseline)" in md
    assert "Versus baseline `a`" in md
    assert "## Environment" in md
    csv_text = (out / "summary.csv").read_text().splitlines()
    assert csv_text[0].startswith("metric,variant,n,mean")
    assert len(csv_text) == 1 + 4 * 2  # 4 metrics x 2 variants

    idx = report.write_index(tmp_path / "results")
    assert "expT_fake" in idx.read_text()


def test_deterministic_detection():
    from research.harness.report import _is_deterministic

    assert _is_deterministic([405.047659, 405.047865, 405.047608])  # byte jitter
    assert _is_deterministic([8.0, 8.0, 8.0])
    assert not _is_deterministic([3.1, 3.4, 2.9])  # real timing variance
    assert not _is_deterministic([1.0])
