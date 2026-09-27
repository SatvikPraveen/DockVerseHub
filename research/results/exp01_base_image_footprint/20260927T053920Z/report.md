# Base image choice: footprint, cold build time and cold start

**Experiment:** `exp01_base_image_footprint`  
**Procedure:** `build`  
**Design:** 5 recorded repetitions, 1 warm-up, block-randomised order, seed 42  
**Baseline:** `full`  
**Recorded trials:** 20 (0 failed)

## Hypothesis

For an identical pure-Python Flask workload, slim, Alpine and distroless bases reduce image size by more than 70% relative to the full Debian image, and reduce cold-start latency measurably; Alpine's musl libc does not change cold start for a pure-Python app.

## Variants

| Variant | Dockerfile | Description |
|---|---|---|
| `full` | `fixtures/base-images/Dockerfile.full` | python:3.12 (Debian bookworm, full toolchain) |
| `slim` | `fixtures/base-images/Dockerfile.slim` | python:3.12-slim |
| `alpine` | `fixtures/base-images/Dockerfile.alpine` | python:3.12-alpine (musl) |
| `distroless` | `fixtures/base-images/Dockerfile.distroless` | gcr.io/distroless/python3-debian12:nonroot, deps via --target |

## Cold build time (s)

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `full` (baseline) | 5 | 3.423 | [2.670, 4.176] | 3.292 | 0.606 | 17.7% |
| `slim` | 5 | 3.376 | [2.763, 3.989] | 3.136 | 0.494 | 14.6% |
| `alpine` | 5 | 3.396 | [3.003, 3.790] | 3.433 | 0.317 | 9.3% |
| `distroless` | 5 | 3.454 | [2.958, 3.949] | 3.307 | 0.399 | 11.5% |

**Versus baseline `full`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `slim` | -0.047 | -1.4% | -0.08 (negligible) | 0.12 | 0.897 | 0.913 |
| `alpine` | -0.027 | -0.8% | -0.06 (negligible) | 0.04 | 0.933 | 0.929 |
| `distroless` | 0.031 | 0.9% | 0.06 (negligible) | 0.20 | 0.928 | 0.952 |

## Image size (MB)

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `full` (baseline) | 5 | 405.048 | [405.048, 405.048] | 405.048 | 0.000 | 0.0% |
| `slim` | 5 | 48.437 | [48.437, 48.437] | 48.437 | 0.000 | 0.0% |
| `alpine` | 5 | 23.456 | [23.456, 23.456] | 23.456 | 0.000 | 0.0% |
| `distroless` | 5 | 20.904 | [20.904, 20.904] | 20.904 | 0.000 | 0.0% |

**Versus baseline `full`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `slim` | -356.611 | -88.0% | n/a (deterministic) | -1.00 | <0.001 | 0.008 |
| `alpine` | -381.592 | -94.2% | n/a (deterministic) | -1.00 | <0.001 | 0.008 |
| `distroless` | -384.144 | -94.8% | n/a (deterministic) | -1.00 | <0.001 | 0.008 |

## Layers

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `full` (baseline) | 5 | 11.000 | [11.000, 11.000] | 11.000 | 0.000 | 0.0% |
| `slim` | 5 | 8.000 | [8.000, 8.000] | 8.000 | 0.000 | 0.0% |
| `alpine` | 5 | 8.000 | [8.000, 8.000] | 8.000 | 0.000 | 0.0% |
| `distroless` | 5 | 46.000 | [46.000, 46.000] | 46.000 | 0.000 | 0.0% |

**Versus baseline `full`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `slim` | -3.000 | -27.3% | n/a (deterministic) | -1.00 | <0.001 | 0.008 |
| `alpine` | -3.000 | -27.3% | n/a (deterministic) | -1.00 | <0.001 | 0.008 |
| `distroless` | 35.000 | 318.2% | n/a (deterministic) | 1.00 | <0.001 | 0.008 |

## Time to ready (s)

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `full` (baseline) | 5 | 0.239 | [0.208, 0.269] | 0.246 | 0.024 | 10.2% |
| `slim` | 5 | 0.340 | [0.054, 0.626] | 0.269 | 0.230 | 67.7% |
| `alpine` | 5 | 0.326 | [0.163, 0.488] | 0.292 | 0.131 | 40.2% |
| `distroless` | 5 | 0.411 | [0.370, 0.452] | 0.396 | 0.033 | 8.1% |

**Versus baseline `full`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `slim` | 0.102 | 42.7% | 0.62 (medium) | 0.12 | 0.380 | 0.484 |
| `alpine` | 0.087 | 36.5% | 0.93 (large) | 0.52 | 0.213 | 0.151 |
| `distroless` | 0.172 | 72.2% | 5.91 (large) | 1.00 | <0.001 | 0.008 |

## Environment

| Field | Value |
|---|---|
| Captured | 2026-09-27T05:39:20.724469+00:00 |
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
