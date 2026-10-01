# DockVerseHub

<!-- BADGES START -->
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Docker Compose](https://img.shields.io/badge/Docker_Compose-2496ED?style=flat&logo=docker&logoColor=white)
![Dockerfiles](https://img.shields.io/badge/Dockerfiles-48-blue?style=flat)
![Compose Files](https://img.shields.io/badge/Compose%20Files-22-green?style=flat)
![Labs](https://img.shields.io/badge/Labs-8-orange?style=flat)
![Concepts](https://img.shields.io/badge/Concepts-13-purple?style=flat)
![Experiments](https://img.shields.io/badge/Experiments-4-teal?style=flat)
![Stars](https://img.shields.io/badge/Stars-0-yellow?style=flat)
![Forks](https://img.shields.io/badge/Forks-0-lightgrey?style=flat)
![Issues](https://img.shields.io/badge/Issues-0-green?style=flat)
![Last Updated](https://img.shields.io/badge/Last%20Updated-2026--10--01-brightgreen?style=flat)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Contributions Welcome](https://img.shields.io/badge/Contributions-Welcome-brightgreen.svg)
<!-- BADGES END -->
[![CI](https://github.com/SatvikPraveen/DockVerseHub/actions/workflows/ci.yml/badge.svg)](https://github.com/SatvikPraveen/DockVerseHub/actions/workflows/ci.yml)
[![Research Benchmarks](https://github.com/SatvikPraveen/DockVerseHub/actions/workflows/research-benchmarks.yml/badge.svg)](https://github.com/SatvikPraveen/DockVerseHub/actions/workflows/research-benchmarks.yml)

> A structured Docker curriculum (13 concept modules, 8 runnable labs) paired with a reproducible benchmarking harness, so that the practices it teaches are measured rather than asserted.

DockVerseHub serves two audiences:

- **Learners.** A progressive path from first `docker run` to Kubernetes, GitOps and observability, with a hands-on lab at each stage.
- **Practitioners and researchers.** Controlled, repeatable container experiments with statistical reports, a written methodology and citable results.

## Contents

- [Quick start](#quick-start)
- [Research: measured, not asserted](#research-measured-not-asserted)
- [Curriculum](#curriculum)
- [Learning paths](#learning-paths)
- [Quality and verification](#quality-and-verification)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Contributing, license and citation](#contributing-license-and-citation)

## Quick start

Requirements: Docker Engine 23+ with the Compose v2 plugin (`docker compose`). Python 3.10+ is needed only for the research harness and the tests.

```bash
git clone https://github.com/SatvikPraveen/DockVerseHub.git
cd DockVerseHub

docker --version && docker compose version

# First lab: a small Flask service (about 15 minutes)
cd labs/lab_01_simple_app
docker compose up --build
```

Then open <http://localhost:8080>. The container reports `healthy` in `docker compose ps` once its health check passes. Stop it with `docker compose down`.

For a guided setup, see [GETTING_STARTED.md](docs/GETTING_STARTED.md).

## Research: measured, not asserted

The `research/` directory contains a benchmarking harness that depends only on the Python standard library and the Docker CLI. It runs declarative experiments with warm-up rounds, a seeded block-randomised trial order and a full environment snapshot. It then reports 95% confidence intervals, Cohen's *d*, Cliff's δ, Welch's *t* and permutation *p*-values against a declared baseline. Each hypothesis is written before any data are collected.

### Findings at a glance

Committed run on macOS arm64 with Docker Engine 29.7, cross-checked on Linux x86-64 in CI. Ratios are what transfer between machines; absolute seconds do not.

| Question | Result | Verdict |
|---|---|---|
| Base image size (slim / Alpine / distroless vs full `python:3.12`) | −88% / −94% / −95% | Supported |
| Does a smaller base start faster? | No: the full image was fastest; distroless was 72% slower | Not supported |
| Copy dependencies before source: rebuild after a source-only edit | 5.0× faster (−80%), every trial | Supported |
| Multi-stage vs single-stage (toolchain discarded) | −67% image size and −28% cold build time | Partly supported |
| BuildKit cache mount for pip, after a manifest change | −14% mean rebuild time, *p* ≈ 0.24 | Inconclusive |

Full analysis, including threats to validity: [research/results/FINDINGS.md](research/results/FINDINGS.md).

### Running the experiments

```bash
python -m research.harness list                    # what is defined
python -m research.harness validate                # definitions and fixtures
python -m research.harness run exp02_layer_cache_effectiveness
python -m research.harness run                     # all four, about 10 minutes
```

Each run writes the frozen design, the environment snapshot, raw trials, a summary and a report to `research/results/<experiment>/<run-id>/`.

| Document | Purpose |
|---|---|
| [research/README.md](research/README.md) | Harness guide and output format |
| [research/METHODOLOGY.md](research/METHODOLOGY.md) | Protocol, statistics, reproduction and threats to validity |
| [research/REFERENCES.md](research/REFERENCES.md) | 33 sources, also as [BibTeX](research/references.bib) |
| [research/results/README.md](research/results/README.md) | Index of committed runs |

## Curriculum

### Concept modules

| # | Module | Topics |
|---|---|---|
| 01 | `getting_started` | Installation, CLI basics, container lifecycle |
| 02 | `images_layers` | Image building, layers, optimisation, registries |
| 03 | `volumes_bindmounts` | Data persistence, backup and restore |
| 04 | `networking` | Container communication, custom networks, load balancing |
| 05 | `docker_compose` | Multi-container apps, profiles, scaling, extensions |
| 06 | `security` | Hardening, rootless containers, secrets, scanning, compliance |
| 07 | `logging_monitoring` | Logging drivers, ELK, Prometheus, Grafana, alerting |
| 08 | `orchestration` | Docker Swarm, placement, rolling updates, service mesh |
| 09 | `advanced_tricks` | BuildKit, build optimisation, resource limits, debugging |
| 10 | `ci_cd_integration` | GitHub Actions, GitLab CI, Jenkins, Azure DevOps, deployment strategies |
| 11 | `kubernetes` | Core objects, deployment patterns, Kubernetes at scale |
| 12 | `gitops_iac` | GitOps, Argo CD, Flux, Terraform, progressive delivery |
| 13 | `observability_monitoring` | Prometheus, Grafana, Jaeger, OpenTelemetry, SLOs and SLIs |

Each module lives in `concepts/<NN>_<name>/` with a README and runnable examples.

### Labs

| Lab | Time | Level | Topics |
|---|---|---|---|
| 01 Simple app | 15–30 min | Beginner | Dockerfile, Compose, health checks |
| 02 Multi-container | 30–45 min | Beginner+ | Full-stack app, networking, volumes |
| 03 Image optimisation | 20–30 min | Intermediate | Multi-stage builds, Alpine, layer caching |
| 04 Logging dashboard | 45–60 min | Intermediate+ | ELK, Prometheus, Grafana |
| 05 Microservices | 60–90 min | Advanced | API gateway, message queues, contract and load tests |
| 06 Production deployment | 90–120 min | Advanced | TLS, backups, health checks, hardening |
| 07 Kubernetes deployment | 2–2.5 h | Advanced | Multi-tier app with Kubernetes manifests |
| 08 Observability stack | 4–5 h | Advanced | Metrics, tracing, dashboards, incident response |

List the labs with `make labs`. Each lab directory has its own README with steps.

### Further reading in the repository

- [docs/](docs/INDEX.md): 49 guides and references (about 28,000 lines), including learning paths, cheat sheets, troubleshooting flowcharts and production guides.
- [case-studies/](case-studies/README.md): anonymised adoption scenarios, from startup scale-up to enterprise rollout. They are illustrative and have not been independently verified.
- [utilities/](utilities/automation/README.md): Dockerfile and Compose templates, profiling and benchmarking scripts, and security hardening guides.

## Learning paths

| Path | Concepts | Labs | Effort | Focus |
|---|---|---|---|---|
| Beginner | 01–05 | 01, 02 | 40–60 h | Fundamentals, Compose, basic networking |
| Intermediate | 06–07 | 03, 04 | 50–70 h | Security, monitoring, optimisation |
| Advanced | 08–10 | 05, 06 | 80–120 h | Orchestration, microservices, CI/CD, production |
| Expert | 11–13 | 07, 08 | 100–150 h | Kubernetes, GitOps, observability |

Detailed curricula, including time-constrained and certification-prep tracks, are in [docs/learning-paths/](docs/learning-paths/).

## Quality and verification

These checks run on every push:

| Check | What it guarantees |
|---|---|
| pytest (370+ tests) | Harness statistics match published t-tables. Every YAML file in the repository parses. Documentation links resolve. Every lab and concept has a README. Dockerfile health checks only use tools the image ships, and `# syntax=` directives are on line 1. |
| ruff and black | Consistent, lint-clean Python in `research/` and `tests/` |
| hadolint | Every Dockerfile is linted against the committed [.hadolint.yaml](.hadolint.yaml) policy |
| Build tests | Representative images (concept 01, lab 01) build in CI |
| Research smoke run | Two experiments run end to end on a GitHub-hosted runner |
| Security scan | Trivy image scanning, CodeQL analysis and Safety dependency checks, plus weekly Dependabot updates |

GitHub Actions runs 7 active workflows: CI, research benchmarks, Dockerfile linting, security scanning, performance testing, release automation and README badge updates.

**Scope of these guarantees.** They catch syntax, structure and a defined set of known mistakes. They do not prove that every example is correct, current or production-safe. The labs are teaching material; review and adapt them before production use. See [SECURITY.md](.github/SECURITY.md) for the security policy.

## Development

```bash
python -m pip install -r requirements.txt -r requirements-dev.txt

make test-unit            # pytest: harness and repository invariants (no Docker needed)
make lint-python          # ruff and black
make research-validate    # experiment definitions and fixtures
make help                 # every other target
```

Optional pre-commit hooks (ruff, black, hadolint, shellcheck, yamllint):

```bash
pip install pre-commit && pre-commit install
```

## Troubleshooting

**Docker is not running.** On macOS or Windows, start Docker Desktop. On Linux, run `sudo systemctl start docker`.

**Port 8080 is already in use.** Find the process with `lsof -i :8080`, or run lab 01 on another port:

```bash
docker compose run --rm -p 8081:5000 simple-app
```

**A container exits or stays unhealthy.**

```bash
docker compose ps                     # state and health
docker compose logs -f                # application output
docker compose run --rm simple-app sh # shell in a fresh container (lab 01)
```

More solutions are in [docs/troubleshooting.md](docs/troubleshooting.md).

## Contributing, license and citation

Contributions are welcome. See [CONTRIBUTING.md](docs/CONTRIBUTING.md), and report bugs or ideas through [GitHub Issues](https://github.com/SatvikPraveen/DockVerseHub/issues). New performance claims should come with an experiment under `research/`, following [METHODOLOGY.md](research/METHODOLOGY.md).

Licensed under the [MIT License](LICENSE).

If you use DockVerseHub or its benchmark harness in academic work, please cite it using [CITATION.cff](CITATION.cff). GitHub's "Cite this repository" button renders it as APA or BibTeX. When citing a specific result, include the experiment ID, the run ID and the commit recorded in that run's `environment.json`.
