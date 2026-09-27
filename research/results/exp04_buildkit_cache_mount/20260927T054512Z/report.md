# BuildKit cache mounts for package-manager downloads

**Experiment:** `exp04_buildkit_cache_mount`  
**Procedure:** `cache_probe`  
**Design:** 7 recorded repetitions, 1 warm-up, block-randomised order, seed 42  
**Baseline:** `plain`  
**Recorded trials:** 14 (0 failed)

## Hypothesis

When requirements.txt changes, a RUN --mount=type=cache on pip's cache directory cuts the rebuild time versus a plain RUN pip install because wheels are served from the persistent cache instead of PyPI. The gain scales with dependency download size and network latency, so it is smaller on a fast connection.

## Variants

| Variant | Dockerfile | Description |
|---|---|---|
| `plain` | `fixtures/buildkit-cache/Dockerfile.plain` | RUN pip install -r requirements.txt |
| `cache-mount` | `fixtures/buildkit-cache/Dockerfile.cache-mount` | RUN --mount=type=cache,target=/root/.cache/pip pip install ... |

## Warm build time (s)

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `plain` (baseline) | 7 | 0.620 | [0.445, 0.795] | 0.575 | 0.189 | 30.5% |
| `cache-mount` | 7 | 0.850 | [0.732, 0.969] | 0.810 | 0.128 | 15.0% |

**Versus baseline `plain`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `cache-mount` | 0.230 | 37.2% | 1.43 (large) | 0.76 | 0.023 | 0.027 |

## Incremental rebuild (s)

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `plain` (baseline) | 7 | 3.407 | [3.051, 3.763] | 3.419 | 0.385 | 11.3% |
| `cache-mount` | 7 | 2.928 | [2.065, 3.790] | 2.745 | 0.933 | 31.9% |

**Versus baseline `plain`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `cache-mount` | -0.479 | -14.1% | -0.67 (medium) | -0.71 | 0.244 | 0.241 |

## Image size (MB)

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `plain` (baseline) | 7 | 49.284 | [49.284, 49.284] | 49.284 | 0.000 | 0.0% |
| `cache-mount` | 7 | 48.437 | [48.437, 48.437] | 48.437 | 0.000 | 0.0% |

**Versus baseline `plain`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `cache-mount` | -0.847 | -1.7% | n/a (deterministic) | -1.00 | <0.001 | <0.001 |

## Layers

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `plain` (baseline) | 7 | 8.000 | [8.000, 8.000] | 8.000 | 0.000 | 0.0% |
| `cache-mount` | 7 | 8.000 | [8.000, 8.000] | 8.000 | 0.000 | 0.0% |

**Versus baseline `plain`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `cache-mount` | 0.000 | 0.0% | n/a (deterministic) | 0.00 | 1.000 | 1.000 |

## Environment

| Field | Value |
|---|---|
| Captured | 2026-09-27T05:45:12.658847+00:00 |
| Host | macOS-26.6.2-arm64-arm-64bit-Mach-O (arm64, 10 CPUs) |
| Docker server | 29.7.2 on Docker Desktop / 7.0.12-linuxkit |
| Storage driver | overlayfs |
| Docker CPUs / memory | 10 / 8.3 GB |
| BuildKit | True (github.com/docker/buildx v0.36.1-desktop.1 83d819cf8237b52ef45a2a9857eeb83a7b10977f) |
| Git commit | 2dd6d16b7ea64ec6ac9edbe2a7ff57af3e94c91a |

## How to read this

- The 95% CI is a Student-t interval on the mean; non-overlapping CIs are strong evidence of a real difference, overlapping CIs are inconclusive on their own.
- A metric marked *deterministic* (image size, layer count) has no run-to-run variance, so Cohen's d is undefined; Δ% and Cliff's δ carry the whole story.
- Cohen's d is the standardised mean difference (|d| < 0.2 negligible, < 0.5 small, < 0.8 medium, else large). Cliff's δ is its rank-based counterpart and is robust to outliers.
- Welch's t-test does not assume equal variances. The permutation test makes no distributional assumption at all; with few repetitions it is the more trustworthy of the two.
- Absolute numbers are specific to this host. Ratios between variants transfer far better than raw values; see research/METHODOLOGY.md, section Threats to validity.
