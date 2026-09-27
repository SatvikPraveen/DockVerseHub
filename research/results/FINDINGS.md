# Findings (run of 2026-09-27)

**Location:** `research/results/FINDINGS.md`
**Host:** macOS 26.6 on Apple Silicon (arm64), Docker Engine 29.7.2 in the Docker Desktop Linux VM
**Harness commit:** `980e53b` (clean tree), recorded in every run's `environment.json`.
The experiment definitions and fixtures used were on disk but, because of a `.gitignore` rule, were first
committed in `cf5b81a`, unchanged. Between the two commits only the report renderer changed, not the
measurement code, and the reports here were regenerated with it from the original `raw.jsonl`.
**Design:** 5 recorded repetitions for build experiments and 7 for cache probes, 1 warm-up round, block-randomised order, seed 42

This page interprets the four committed runs against the hypotheses written **before** the data were collected. Hypotheses were not edited afterwards. The full statistics are in each run's `report.md`. Absolute numbers are specific to this host. The ratios between variants are the part that should transfer.

## Summary

| RQ | Hypothesis | Verdict |
|----|-----------|---------|
| RQ1 size | Slim, Alpine and distroless shrink the image by more than 70% | **Supported.** The reductions were 88%, 94% and 95%. |
| RQ1 cold start | Smaller bases start measurably faster | **Not supported.** The full image was the fastest to become ready. |
| RQ2 | Deps-first rebuilds a source-only edit more than 5 times faster, with a large effect | **Supported.** It was 5.0 times faster, with Cliff's δ of −1.00. |
| RQ3 | Multi-stage saves hundreds of MB at a small build-time cost | **Partly supported.** It saved 98 MB (67%), and the build was *faster*, not slower. |
| RQ4 | A cache mount cuts rebuild time after a manifest change | **Inconclusive.** The mean was 14% lower, but p ≈ 0.24. |

## RQ1: Base image choice (`exp01_base_image_footprint`)

| Variant | Image size (MB) | Δ vs full | Cold build (s) | Time to ready (s, mean) |
|---|---:|---:|---:|---:|
| full (`python:3.12`) | 405.0 | baseline | 3.42 | 0.239 |
| slim | 48.4 | −88.0% | 3.38 | 0.340 |
| alpine | 23.5 | −94.2% | 3.40 | 0.326 |
| distroless | 20.9 | −94.8% | 3.45 | 0.411 |

- **Size.** The hypothesis is strongly supported. Every minimal base is roughly an order of magnitude smaller. Size is deterministic up to byte-level jitter, so Cliff's δ = −1.00 and Δ% are the meaningful statistics.
- **Cold build time.** There is no difference: every |d| is below 0.1 and every p is above 0.89. Base layers were already local after warm-up, so this run measures only the `pip install` and `COPY` steps, which are identical across variants. A registry-cold comparison would need `prune_between_trials`.
- **Cold start.** The prediction was wrong. The full image was the *fastest* to answer `/health`. Distroless was the slowest, 72% slower than full, with d = 5.9 and permutation p = 0.008. Slim and Alpine were not significantly different from full, because their variance was high (CV 40–68%). A plausible explanation is that the full image's layers were hot in the VM page cache. Distroless also runs Python 3.11 with `PYTHONPATH`-based imports rather than site-packages. **Takeaway:** choose a minimal base for size, attack surface and pull time. Do not expect it to improve process start-up on a warm host.

## RQ2: Layer ordering (`exp02_layer_cache_effectiveness`)

| Variant | Incremental rebuild (s) | 95% CI |
|---|---:|---|
| source-first (`COPY . .` then `pip install`) | 3.13 | [2.87, 3.39] |
| deps-first (`COPY requirements.txt`, install, then `COPY . .`) | 0.62 | [0.55, 0.70] |

After a one-line edit to `app.py`, deps-first rebuilt 80% faster, a ratio of 5.0. The confidence intervals are far apart, and Cliff's δ = −1.00: every deps-first trial beat every source-first trial. The effect would grow with a heavier dependency set, because source-first pays the whole install again. This result is the strongest empirical support in the repository for the Dockerfile ordering advice in `concepts/02_images_layers` and `labs/lab_03_image_optimization`.

## RQ3: Multi-stage builds (`exp03_multistage_vs_single`)

| Variant | Image size (MB) | Cold build (s) | Time to ready (s) |
|---|---:|---:|---:|
| single-stage (toolchain kept) | 147.2 | 20.04 | 0.666 |
| multi-stage (toolchain discarded) | 49.0 | 14.51 | 0.262 |

- **Size.** The multi-stage image saved 98 MB (−66.7%). That is less than "hundreds of MB", because `build-essential` on slim is about 100 MB. The direction was predicted correctly and the magnitude was overstated.
- **Build time.** The prediction was wrong in a useful way. Multi-stage was 28% *faster*, with d = −6.3. BuildKit builds independent stages concurrently and exports a much smaller final image. The extra wheel-packaging step cost less than the export it avoided.
- **Time to ready.** Multi-stage was 61% faster (p = 0.008). Treat this as secondary. Image size and page-cache state are confounded here, and the single-stage variance was high (CV 26%).

## RQ4: BuildKit cache mounts (`exp04_buildkit_cache_mount`)

| Variant | Rebuild after manifest change (s) | 95% CI |
|---|---:|---|
| plain `pip install` | 3.41 | [3.05, 3.76] |
| `--mount=type=cache,target=/root/.cache/pip` | 2.93 | [2.07, 3.79] |

The mean fell by 14%, with a medium effect: d = −0.67 and Cliff's δ = −0.71. However, Welch p = 0.24 and permutation p = 0.24, so seven repetitions cannot tell the effect apart from noise. The fixture has only seven small pure-Python wheels and the network was fast, so the download term the cache mount removes is small. The methodology predicted exactly this. The next step is to raise the repetitions and add a fixture with heavy dependencies such as numpy or pandas before drawing a conclusion.

## Cross-platform check (CI, Linux x86-64)

GitHub Actions run `36299030634` (commit `61a6713`) executed the two `ci-smoke` experiments on a hosted runner with Linux 6.17 on x86-64 (Azure). It used 2 repetitions, so it serves as a direction-and-magnitude check, not a citable measurement.

| Result | macOS arm64 (this run) | Linux x86-64 (CI) |
|---|---:|---:|
| RQ2: deps-first incremental rebuild vs source-first | −80.1% | −79.4% |
| RQ1: slim / alpine / distroless image size vs full | −88.0 / −94.2 / −94.8% | −88.2 / −94.5 / −94.8% |
| RQ1: distroless time-to-ready vs full | +72.2% | +71.9% |

The ratios agree closely across CPU architectures, operating systems and virtualisation layers. That is the transferability METHODOLOGY.md predicts for ratios, and it strengthens the RQ1 size, RQ2 and distroless cold-start conclusions. The small slim and Alpine cold-start differences remain inconclusive on both platforms.

## Threats specific to this run

- Docker Desktop on macOS adds a virtualisation layer and a shared page cache. On native Linux the cold-start numbers will be lower and may rank differently.
- One run on one host. Results that rely on large effects (RQ1 size, RQ2, RQ3 size) are robust to this. Results with small or unexpected effects (RQ1 cold start, RQ4) should be replicated before anyone cites them.
- Base-image tags (`python:3.12-slim` and others) are not pinned by digest. A future rebuild may pull different layers.

## Reproduce

```bash
git checkout cf5b81a            # first commit containing harness + experiment fixtures
python -m research.harness run            # ~10 minutes on the host above
python -m research.harness index
```

Compare your treatment/baseline ratios to the tables above, not your absolute seconds.
