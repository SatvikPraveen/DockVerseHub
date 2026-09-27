# Layer ordering and cache effectiveness on source-only changes

**Experiment:** `exp02_layer_cache_effectiveness`  
**Procedure:** `cache_probe`  
**Design:** 7 recorded repetitions, 1 warm-up, block-randomised order, seed 42  
**Baseline:** `source-first`  
**Recorded trials:** 14 (0 failed)

## Hypothesis

Copying and installing dependencies before application source lets a source-only edit rebuild in well under a second of layer work, whereas copying the whole context first invalidates the dependency layer and makes every edit pay the full pip install cost. Expected effect size: large (d > 0.8), rebuild time ratio > 5x.

## Variants

| Variant | Dockerfile | Description |
|---|---|---|
| `source-first` | `fixtures/layer-cache/Dockerfile.source-first` | COPY . . before pip install (anti-pattern) |
| `deps-first` | `fixtures/layer-cache/Dockerfile.deps-first` | COPY requirements.txt + pip install before COPY . . |

## Warm build time (s)

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `source-first` (baseline) | 7 | 0.531 | [0.461, 0.600] | 0.514 | 0.075 | 14.2% |
| `deps-first` | 7 | 0.561 | [0.514, 0.608] | 0.533 | 0.051 | 9.2% |

**Versus baseline `source-first`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `deps-first` | 0.030 | 5.7% | 0.47 (small) | 0.35 | 0.398 | 0.392 |

## Incremental rebuild (s)

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `source-first` (baseline) | 7 | 3.131 | [2.869, 3.394] | 3.014 | 0.283 | 9.1% |
| `deps-first` | 7 | 0.623 | [0.549, 0.696] | 0.625 | 0.080 | 12.8% |

**Versus baseline `source-first`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `deps-first` | -2.509 | -80.1% | -12.05 (large) | -1.00 | <0.001 | <0.001 |

## Image size (MB)

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `source-first` (baseline) | 7 | 48.437 | [48.436, 48.437] | 48.437 | 0.000 | 0.0% |
| `deps-first` | 7 | 48.437 | [48.437, 48.437] | 48.437 | 0.000 | 0.0% |

**Versus baseline `source-first`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `deps-first` | 0.001 | 0.0% | n/a (deterministic) | 1.00 | <0.001 | <0.001 |

## Layers

_Lower is better._

| Variant | n | mean | 95% CI (t) | median | sd | CV |
|---|---:|---:|:---:|---:|---:|---:|
| `source-first` (baseline) | 7 | 7.000 | [7.000, 7.000] | 7.000 | 0.000 | 0.0% |
| `deps-first` | 7 | 8.000 | [8.000, 8.000] | 8.000 | 0.000 | 0.0% |

**Versus baseline `source-first`**

| Variant | Δ | Δ% | Cohen's d | Cliff's δ | Welch p | Permutation p |
|---|---:|---:|---:|---:|---:|---:|
| `deps-first` | 1.000 | 14.3% | n/a (deterministic) | 1.00 | <0.001 | <0.001 |

## Environment

| Field | Value |
|---|---|
| Captured | 2026-09-27T05:40:55.707879+00:00 |
| Host | macOS-26.6.2-arm64-arm-64bit-Mach-O (arm64, 10 CPUs) |
| Docker server | 29.7.2 on Docker Desktop / 7.0.12-linuxkit |
| Storage driver | overlayfs |
| Docker CPUs / memory | 10 / 8.3 GB |
| BuildKit | True (github.com/docker/buildx v0.36.1-desktop.1 83d819cf8237b52ef45a2a9857eeb83a7b10977f) |
| Git commit | 980e53bad79df5bbc39873e002c3662b12d56846 |

## How to read this

- The 95% CI is a Student-t interval on the mean; non-overlapping CIs are strong evidence of a real difference, overlapping CIs are inconclusive on their own.
- A metric marked *deterministic* (image size, layer count) has no run-to-run variance, so Cohen's d is undefined; Δ% and Cliff's δ carry the whole story.
- Cohen's d is the standardised mean difference (|d| < 0.2 negligible, < 0.5 small, < 0.8 medium, else large). Cliff's δ is its rank-based counterpart and is robust to outliers.
- Welch's t-test does not assume equal variances. The permutation test makes no distributional assumption at all; with few repetitions it is the more trustworthy of the two.
- Absolute numbers are specific to this host. Ratios between variants transfer far better than raw values; see research/METHODOLOGY.md, section Threats to validity.
