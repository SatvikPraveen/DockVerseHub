# Location: research/harness/__main__.py
"""Command-line entry point: python -m research.harness <command>."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from . import docker_ops, report
from .runner import Experiment, Runner

RESEARCH_DIR = Path(__file__).resolve().parent.parent
EXPERIMENTS_DIR = RESEARCH_DIR / "experiments"
RESULTS_DIR = RESEARCH_DIR / "results"


def _experiment_files() -> list[Path]:
    return sorted(EXPERIMENTS_DIR.glob("exp*.json"))


def cmd_list(_: argparse.Namespace) -> int:
    for p in _experiment_files():
        e = Experiment.load(p)
        print(
            f"{e.id:40s} {e.procedure:12s} {len(e.variants)} variants  reps={e.repetitions}  {e.title}"
        )
    return 0


def cmd_validate(_: argparse.Namespace) -> int:
    bad = 0
    for p in _experiment_files():
        try:
            e = Experiment.load(p)
            for v in e.variants:
                for rel in (v.dockerfile, v.context):
                    if not (EXPERIMENTS_DIR / rel).exists():
                        raise FileNotFoundError(rel)
            print(f"ok   {p.name}")
        except Exception as exc:
            bad += 1
            print(f"FAIL {p.name}: {exc}")
    return 1 if bad else 0


def cmd_run(args: argparse.Namespace) -> int:
    if not docker_ops.daemon_available():
        print("error: Docker daemon not reachable", file=sys.stderr)
        return 2
    wanted = set(args.experiments)
    files = [
        p
        for p in _experiment_files()
        if not wanted or p.stem in wanted or Experiment.load(p).id in wanted
    ]
    if wanted and len(files) != len(wanted):
        print(f"error: unknown experiment(s): {wanted - {p.stem for p in files}}", file=sys.stderr)
        return 2
    results_dir = Path(args.results_dir)
    for p in files:
        exp = Experiment.load(p)
        if args.tag and not (set(args.tag) & set(exp.tags)):
            continue
        runner = Runner(
            exp,
            EXPERIMENTS_DIR,
            results_dir,
            repetitions=args.repetitions,
            warmup=args.warmup,
            run_id=args.run_id,
        )
        out = runner.run()
        summary = report.write_report(out)
        print(
            f"  -> {out / 'report.md'}  ({summary['trials_recorded']} trials, {summary['trials_failed']} failed)"
        )
        if summary["trials_failed"] and args.strict:
            return 1
    report.write_index(results_dir)
    return 0


def cmd_report(args: argparse.Namespace) -> int:
    for d in args.run_dirs:
        s = report.write_report(Path(d))
        print(f"{d}: {s['trials_recorded']} trials, {s['trials_failed']} failed -> report.md")
    return 0


def cmd_index(args: argparse.Namespace) -> int:
    print(report.write_index(Path(args.results_dir)))
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog="python -m research.harness", description="DockVerseHub research harness"
    )
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("list", help="list experiments").set_defaults(fn=cmd_list)
    sub.add_parser("validate", help="validate experiment definitions and fixtures").set_defaults(
        fn=cmd_validate
    )

    r = sub.add_parser("run", help="run one or more experiments")
    r.add_argument("experiments", nargs="*", help="experiment ids (default: all)")
    r.add_argument("--repetitions", type=int, default=None, help="override recorded repetitions")
    r.add_argument("--warmup", type=int, default=None, help="override warm-up rounds")
    r.add_argument("--results-dir", default=str(RESULTS_DIR))
    r.add_argument("--run-id", default=None, help="fixed run id (default: UTC timestamp)")
    r.add_argument(
        "--tag", action="append", help="only run experiments carrying this tag (repeatable)"
    )
    r.add_argument("--strict", action="store_true", help="exit non-zero if any trial failed")
    r.set_defaults(fn=cmd_run)

    rp = sub.add_parser("report", help="(re)generate summary + report for run directories")
    rp.add_argument("run_dirs", nargs="+")
    rp.set_defaults(fn=cmd_report)

    ix = sub.add_parser("index", help="regenerate results/README.md")
    ix.add_argument("--results-dir", default=str(RESULTS_DIR))
    ix.set_defaults(fn=cmd_index)

    args = ap.parse_args(argv)
    return int(args.fn(args))


if __name__ == "__main__":
    sys.exit(main())
