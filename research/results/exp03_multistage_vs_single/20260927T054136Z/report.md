# Multi-stage builds: runtime image size versus build cost

**Experiment:** `exp03_multistage_vs_single`  
**Procedure:** `build`  
**Design:** 5 recorded repetitions, 1 warm-up, block-randomised order, seed 42  
**Baseline:** `single-stage`  
**Recorded trials:** 10 (0 failed)

## Hypothesis

A multi-stage build that discards the compiler toolchain produces a runtime image that is hundreds of MB smaller than the single-stage equivalent, at the cost of a small increase in cold build time due to the extra stage and wheel packaging step.

## Variants

| Variant | Dockerfile | Description |
|---|---|---|
| `single-stage` | `fixtures/multistage/Dockerfile.single` | slim + build-essential kept in final image |
| `multi-stage` | `fixtures/multistage/Dockerfile.multi` | builder stage compiles wheels; runtime is plain slim |

## Cold build time (s)

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `single-stage` (baseline) | 5 | 20.037 | [18.558, 21.516] | 20.624 | 1.191 | 5.9% |
| `multi-stage` | 5 | 14.508 | [14.056, 14.961] | 14.300 | 0.364 | 2.5% |

**Versus baseline `single-stage`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `multi-stage` | -5.529 | -27.6% | -6.28 (large) | -1.00 | <0.001 | 0.008 |

## Image size (MB)

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `single-stage` (baseline) | 5 | 147.164 | [147.164, 147.165] | 147.164 | 0.000 | 0.0% |
| `multi-stage` | 5 | 49.039 | [49.038, 49.039] | 49.039 | 0.000 | 0.0% |

**Versus baseline `single-stage`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `multi-stage` | -98.126 | -66.7% | n/a (deterministic) | -1.00 | <0.001 | 0.008 |

## Layers

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `single-stage` (baseline) | 5 | 9.000 | [9.000, 9.000] | 9.000 | 0.000 | 0.0% |
| `multi-stage` | 5 | 8.000 | [8.000, 8.000] | 8.000 | 0.000 | 0.0% |

**Versus baseline `single-stage`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `multi-stage` | -1.000 | -11.1% | n/a (deterministic) | -1.00 | <0.001 | 0.008 |

## Time to ready (s)

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `single-stage` (baseline) | 5 | 0.666 | [0.448, 0.885] | 0.644 | 0.176 | 26.4% |
| `multi-stage` | 5 | 0.262 | [0.229, 0.295] | 0.259 | 0.027 | 10.2% |

**Versus baseline `single-stage`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `multi-stage` | -0.404 | -60.7% | -3.21 (large) | -1.00 | 0.006 | 0.008 |

## Environment

| Field | Value |
|---|---|
| Captured | 2026-09-27T05:41:36.969278+00:00 |
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
