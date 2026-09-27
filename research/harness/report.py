# Location: research/harness/report.py
"""Turn raw measurements into summary.json, summary.csv and report.md."""

from __future__ import annotations

import csv
import json
import math
from collections import defaultdict
from pathlib import Path
from typing import Any

from . import stats

METRIC_META: dict[str, tuple[str, str, bool]] = {
    # metric: (label, unit, lower_is_better)
    "build_time_s": ("Cold build time", "s", True),
    "image_size_mb": ("Image size", "MB", True),
    "layer_count": ("Layers", "", True),
    "time_to_ready_s": ("Time to ready", "s", True),
    "warm_build_s": ("Warm build time", "s", True),
    "incremental_rebuild_s": ("Incremental rebuild", "s", True),
}


def _fmt(x: float, digits: int = 3) -> str:
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return "n/a"
    if isinstance(x, float) and math.isinf(x):
        return "inf"
    return f"{x:.{digits}f}"


def _pfmt(p: float) -> str:
    if p is None or math.isnan(p):
        return "n/a"
    return "<0.001" if p < 0.001 else f"{p:.3f}"


def collect(raw: list[dict[str, Any]]) -> dict[str, dict[str, list[float]]]:
    """metric -> variant -> recorded, successful values (in round order)."""
    out: dict[str, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))
    for rec in sorted(raw, key=lambda r: (r["round"], r["position_in_round"])):
        if not rec.get("recorded") or rec.get("status") != "ok":
            continue
        for m, v in rec.get("metrics", {}).items():
            out[m][rec["variant"]].append(float(v))
    return out


def summarize_run(run_dir: Path) -> dict[str, Any]:
    exp = json.loads((run_dir / "experiment.json").read_text(encoding="utf-8"))
    env = json.loads((run_dir / "environment.json").read_text(encoding="utf-8"))
    raw = [
        json.loads(line)
        for line in (run_dir / "raw.jsonl").read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    data = collect(raw)
    baseline = exp["baseline"]
    seed = int(exp.get("design", {}).get("seed", 42))
    failures = [r for r in raw if r.get("status") != "ok"]

    metrics_out: dict[str, Any] = {}
    for metric, by_variant in data.items():
        entry: dict[str, Any] = {"variants": {}, "comparisons": {}}
        for variant, values in by_variant.items():
            s = stats.summarize(values).to_dict()
            if len(values) >= 2:
                s["bootstrap_ci95"] = list(stats.bootstrap_ci(values, seed=seed))
            s["values"] = values
            entry["variants"][variant] = s
        base_vals = by_variant.get(baseline, [])
        for variant, values in by_variant.items():
            if variant == baseline or not base_vals or not values:
                continue
            entry["comparisons"][variant] = stats.compare(base_vals, values, seed=seed).to_dict()
        metrics_out[metric] = entry

    return {
        "experiment": exp,
        "environment": env,
        "run_dir": str(run_dir),
        "trials_recorded": sum(1 for r in raw if r.get("recorded")),
        "trials_failed": len(failures),
        "failures": [
            {"variant": f["variant"], "round": f["round"], "error": f["error"]} for f in failures
        ],
        "metrics": metrics_out,
    }


def write_csv(summary: dict[str, Any], path: Path) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(
            [
                "metric",
                "variant",
                "n",
                "mean",
                "median",
                "stdev",
                "cv",
                "ci95_low",
                "ci95_high",
                "min",
                "max",
            ]
        )
        for metric, entry in summary["metrics"].items():
            for variant, s in entry["variants"].items():
                w.writerow(
                    [
                        metric,
                        variant,
                        s["n"],
                        s["mean"],
                        s["median"],
                        s["stdev"],
                        s["cv"],
                        s["ci95_low"],
                        s["ci95_high"],
                        s["minimum"],
                        s["maximum"],
                    ]
                )


def render_markdown(summary: dict[str, Any]) -> str:
    exp = summary["experiment"]
    env = summary["environment"]
    baseline = exp["baseline"]
    lines: list[str] = []
    lines.append(f"# {exp['title']}")
    lines.append("")
    lines.append(f"**Experiment:** `{exp['id']}`  ")
    lines.append(f"**Procedure:** `{exp['procedure']}`  ")
    lines.append(
        f"**Design:** {exp['design']['repetitions']} recorded repetitions, {exp['design']['warmup']} warm-up, block-randomised order, seed {exp['design']['seed']}  "
    )
    lines.append(f"**Baseline:** `{baseline}`  ")
    lines.append(
        f"**Recorded trials:** {summary['trials_recorded']} ({summary['trials_failed']} failed)"
    )
    lines.append("")
    lines.append("## Hypothesis")
    lines.append("")
    lines.append(exp["hypothesis"])
    lines.append("")
    lines.append("## Variants")
    lines.append("")
    lines.append("| Variant | Dockerfile | Description |")
    lines.append("|---|---|---|")
    for v in exp["variants"]:
        lines.append(f"| `{v['name']}` | `{v['dockerfile']}` | {v.get('description', '')} |")
    lines.append("")

    for metric, entry in summary["metrics"].items():
        label, unit, lower_better = METRIC_META.get(metric, (metric, "", True))
        unit_s = f" ({unit})" if unit else ""
        lines.append(f"## {label}{unit_s}")
        lines.append("")
        lines.append(f"_{'Lower' if lower_better else 'Higher'} is better._")
        lines.append("")
        lines.append("| Variant | n | mean | 95% CI (t) | median | sd | CV |")
        lines.append("|---|---:|---:|:---:|---:|---:|---:|")
        for variant, s in entry["variants"].items():
            marker = " (baseline)" if variant == baseline else ""
            lines.append(
                f"| `{variant}`{marker} | {s['n']} | {_fmt(s['mean'])} | [{_fmt(s['ci95_low'])}, {_fmt(s['ci95_high'])}] | {_fmt(s['median'])} | {_fmt(s['stdev'])} | {_fmt(100 * s['cv'], 1)}% |"
            )
        if entry["comparisons"]:
            lines.append("")
            lines.append(f"**Versus baseline `{baseline}`**")
            lines.append("")
            lines.append("| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |")
            lines.append("|---|---:|---:|---:|---:|---:|---:|")
            for variant, c in entry["comparisons"].items():
                d_label = stats.interpret_d(c["cohens_d"])
                lines.append(
                    f"| `{variant}` | {_fmt(c['delta'])} | {_fmt(c['delta_pct'], 1)}% | {_fmt(c['cohens_d'], 2)} ({d_label}) | {_fmt(c['cliffs_delta'], 2)} | {_pfmt(c['welch_p'])} | {_pfmt(c['permutation_p'])} |"
                )
        lines.append("")

    if summary["failures"]:
        lines.append("## Failed trials")
        lines.append("")
        for f in summary["failures"]:
            first = (f["error"] or "").splitlines()[0]
            lines.append(f"- round {f['round']} `{f['variant']}`: {first}")
        lines.append("")

    d = env.get("docker", {})
    h = env.get("host", {})
    lines.append("## Environment")
    lines.append("")
    lines.append("| Field | Value |")
    lines.append("|---|---|")
    lines.append(f"| Captured | {env.get('captured_at')} |")
    lines.append(f"| Host | {h.get('platform')} ({h.get('machine')}, {h.get('cpu_count')} CPUs) |")
    lines.append(
        f"| Docker server | {d.get('ServerVersion')} on {d.get('OperatingSystem')} / {d.get('KernelVersion')} |"
    )
    lines.append(f"| Storage driver | {d.get('Driver')} |")
    lines.append(
        f"| Docker CPUs / memory | {d.get('NCPU')} / {_fmt((d.get('MemTotal') or 0) / 1e9, 1)} GB |"
    )
    lines.append(f"| BuildKit | {d.get('buildkit_enabled')} ({d.get('buildx_version')}) |")
    lines.append(
        f"| Git commit | {env.get('git', {}).get('commit')}{' (dirty)' if env.get('git', {}).get('dirty') else ''} |"
    )
    lines.append("")
    lines.append("## How to read this")
    lines.append("")
    lines.append(
        "- The 95% CI is a Student-t interval on the mean; non-overlapping CIs are strong evidence of a real difference, overlapping CIs are inconclusive on their own."
    )
    lines.append(
        "- Cohen's d is the standardised mean difference (|d| < 0.2 negligible, < 0.5 small, < 0.8 medium, else large). Cliff's δ is its rank-based counterpart and is robust to outliers."
    )
    lines.append(
        "- Welch's t-test does not assume equal variances. The permutation test makes no distributional assumption at all; with few repetitions it is the more trustworthy of the two."
    )
    lines.append(
        "- Absolute numbers are specific to this host. Ratios between variants transfer far better than raw values; see research/METHODOLOGY.md, section Threats to validity."
    )
    lines.append("")
    return "\n".join(lines)


def write_report(run_dir: Path) -> dict[str, Any]:
    summary = summarize_run(run_dir)
    (run_dir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    write_csv(summary, run_dir / "summary.csv")
    (run_dir / "report.md").write_text(render_markdown(summary), encoding="utf-8")
    return summary


def write_index(results_dir: Path) -> Path:
    """Regenerate results/README.md listing every run with a one-line verdict."""
    rows: list[str] = []
    for exp_dir in sorted(p for p in results_dir.iterdir() if p.is_dir()):
        for run_dir in sorted(p for p in exp_dir.iterdir() if p.is_dir()):
            sp = run_dir / "summary.json"
            if not sp.exists():
                continue
            s = json.loads(sp.read_text(encoding="utf-8"))
            host = s["environment"].get("host", {}).get("platform", "?")
            rel = run_dir.relative_to(results_dir)
            rows.append(
                f"| `{exp_dir.name}` | `{run_dir.name}` | {s['trials_recorded']} | {s['trials_failed']} | {host} | [report]({rel}/report.md) |"
            )
    text = [
        "# Research results",
        "",
        "Every sub-directory is one run: `<experiment>/<run-id>/` containing `experiment.json` (the frozen design),",
        "`environment.json` (host and Docker snapshot), `raw.jsonl` (every trial, append-only),",
        "`summary.json` / `summary.csv` (statistics) and `report.md` (human-readable).",
        "",
        "Regenerate this index with `python -m research.harness index`.",
        "",
        "| Experiment | Run | Trials | Failed | Host | Report |",
        "|---|---|---:|---:|---|---|",
        *rows,
        "",
    ]
    out = results_dir / "README.md"
    out.write_text("\n".join(text), encoding="utf-8")
    return out
