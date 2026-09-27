# DockVerseHub Research

**Location:** `research/`

A small, dependency-free framework for running **controlled, repeatable container experiments** and reporting them with confidence intervals, effect sizes and significance tests. It exists so that the claims made throughout `concepts/` and `labs/` ("slim images are smaller", "order your COPY instructions", "use cache mounts") are backed by measurements you can rerun on your own machine and compare.

Read [METHODOLOGY.md](METHODOLOGY.md) before trusting or extending any result. Sources are in [REFERENCES.md](REFERENCES.md).

## Layout

```
research/
├── harness/            the framework (python -m research.harness ...)
│   ├── stats.py        t-CI, bootstrap, Cohen's d, Cliff's δ, Welch, permutation test
│   ├── docker_ops.py   timed Docker CLI wrappers, readiness polling, scratch contexts
│   ├── environment.py  host / Docker / git snapshot stored with every run
│   ├── runner.py       experiment loader, warm-up, block-randomised trials, raw.jsonl
│   ├── report.py       summary.json, summary.csv, report.md, results index
│   └── __main__.py     CLI
├── experiments/        one JSON per experiment + fixtures/ (Dockerfiles, workload)
├── results/            committed runs: <experiment>/<run-id>/{raw.jsonl, report.md, ...}
├── tests/              unit tests with a fake Docker backend (no daemon needed)
├── METHODOLOGY.md      the protocol every result must follow
├── REFERENCES.md       annotated bibliography (+ references.bib)
└── README.md           this file
```

## Experiments

| ID | Question | Procedure | Variants |
|----|----------|-----------|----------|
| `exp01_base_image_footprint` | Size, cold build and cold start across base images | build | full, slim, alpine, distroless |
| `exp02_layer_cache_effectiveness` | Incremental rebuild cost of a source-only edit | cache_probe | source-first, deps-first |
| `exp03_multistage_vs_single` | Runtime size vs build cost of multi-stage builds | build | single-stage, multi-stage |
| `exp04_buildkit_cache_mount` | Rebuild cost after a manifest change with `--mount=type=cache` | cache_probe | plain, cache-mount |

Committed results, with the environment they were produced on, are indexed in [results/README.md](results/README.md).

## Quick start

Requirements: Python 3.10+ and a running Docker daemon with BuildKit (Docker 23+). The harness itself imports only the standard library.

```bash
# from the repository root
python -m research.harness list                      # what is defined
python -m research.harness validate                  # definitions + fixture paths
python -m research.harness run exp02_layer_cache_effectiveness
python -m research.harness run                       # everything, default repetitions
python -m research.harness run --tag ci-smoke --repetitions 2 --warmup 1
python -m research.harness report research/results/exp01_base_image_footprint/<run-id>
python -m research.harness index                     # regenerate results/README.md
```

Or via make: `make research-validate`, `make research-run`, `make research-smoke`, `make research-report`.

Unit tests (no Docker required):

```bash
pytest research/tests
```

## What a run produces

```
results/<experiment>/<run-id>/
├── experiment.json    the design, frozen at run time
├── environment.json   host, Docker, BuildKit, git commit (+dirty flag)
├── raw.jsonl          every trial, one JSON object per line, append-only
├── summary.json       per-metric, per-variant statistics and comparisons
├── summary.csv        the same descriptive table for spreadsheets/R/pandas
└── report.md          human-readable report with CIs, effect sizes, p-values
```

## Reading a report

Each metric table gives, per variant, the mean with its 95 % Student-t confidence interval, the median, standard deviation and coefficient of variation. The comparison table gives, for every non-baseline variant, the absolute and relative difference, Cohen's *d* (with Cohen's verbal label), Cliff's δ, Welch's two-sided *p* and a permutation *p*. Effect sizes tell you whether a difference matters; *p*-values tell you whether it is distinguishable from noise at this sample size. Absolute numbers are host-specific; ratios transfer.

## Design principles

- **One factor at a time.** Every experiment varies the Dockerfile and nothing else. The workload is a constant, fully pinned Flask service.
- **Interleaved, seeded order.** Variants are shuffled within each round from a fixed seed, so host drift cannot favour one variant and the sequence is reproducible.
- **Warm-up before recording.** Base images and registry state are primed by an unrecorded round.
- **Nothing hidden.** Failures are recorded, not retried. Raw trials are committed next to summaries. The environment is captured automatically.
- **No heavy dependencies.** Statistics are implemented on the standard library and unit-tested against published tables, so a result can be regenerated on any machine with Python and Docker.

## Continuous integration

`.github/workflows/research-benchmarks.yml` runs the unit tests, validates definitions, then executes the `ci-smoke` experiments with two repetitions on a GitHub-hosted runner and publishes the reports as a build artifact and job summary. CI numbers are for **detecting breakage**, not for citing: hosted runners are shared, virtualised and vary between jobs. Citable results are produced on a dedicated host and committed under `results/`.

## Citing

See [`CITATION.cff`](../CITATION.cff) at the repository root. When citing a specific result, cite the run directory (experiment id + run id) and the git commit recorded in its `environment.json`.
