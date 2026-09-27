# Experimental Methodology

**Location:** `research/METHODOLOGY.md`
**Applies to:** every experiment under `research/experiments/` and every result under `research/results/`
**Version:** 1.0 (2026-09-27)

This document is the protocol. A result that was not produced by following it is not a DockVerseHub research result, whatever directory it sits in.

---

## 1. Purpose

The teaching material in `concepts/` and `labs/` makes many quantitative claims: "slim images are much smaller", "put `COPY requirements.txt` before `COPY . .`", "multi-stage builds shrink the runtime image", "cache mounts speed up rebuilds". Each claim is usually supported by a single screenshot from a single machine. The research harness exists to replace anecdotes with **controlled, repeated, statistically summarised measurements** whose environment is recorded well enough that a reader can reproduce them.

The goal is not to publish the fastest possible numbers. It is to make every number *defensible*: to know its uncertainty, to know what it depends on, and to know how far it can be generalised.

## 2. Research questions

| ID | Question | Experiment | Primary metric(s) |
|----|----------|------------|-------------------|
| RQ1 | How much do base-image choices (full Debian, slim, Alpine, distroless) change image size, cold build time and cold-start latency for an identical pure-Python service? | `exp01_base_image_footprint` | `image_size_mb`, `build_time_s`, `time_to_ready_s` |
| RQ2 | What is the incremental rebuild cost of a source-only change when dependencies are installed before versus after the source is copied? | `exp02_layer_cache_effectiveness` | `incremental_rebuild_s` |
| RQ3 | What does a multi-stage build save in runtime image size, and what does it cost in cold build time? | `exp03_multistage_vs_single` | `image_size_mb`, `build_time_s` |
| RQ4 | When the dependency manifest changes, how much rebuild time does a BuildKit `--mount=type=cache` on the package-manager cache recover? | `exp04_buildkit_cache_mount` | `incremental_rebuild_s` |

Each experiment file states a falsifiable **hypothesis** with an expected direction and, where possible, an expected effect size. The report either supports or contradicts it; the hypothesis is never edited after the data are collected.

## 3. Experimental design

### 3.1 Factors and levels

Every experiment varies exactly **one factor** (the Dockerfile) across a small number of **levels** (variants). Everything else is held constant:

- **Workload.** All variants build and run the same application (`experiments/fixtures/app`): a Flask service that answers `/health`. It does no work of its own, so measured differences are attributable to the image, not to the application.
- **Dependencies.** `requirements.txt` is fully pinned (every transitive package, exact version). Every variant installs byte-identical Python packages.
- **Host.** One run is one host, one Docker daemon, one point in time. Runs are never merged across hosts.

### 3.2 Baseline

Each experiment declares a **baseline** variant. All comparisons are treatment-versus-baseline. The baseline is always the *conventional* or *naive* choice (full image, source-first copy, single stage, plain `pip install`) so that effect sizes read as "what you gain by doing the recommended thing".

### 3.3 Dependent variables

| Metric | Definition | Measured by |
|--------|------------|-------------|
| `build_time_s` | Wall-clock seconds of `docker build --no-cache` | `time.perf_counter()` around the CLI call |
| `image_size_mb` | `docker image inspect --format {{.Size}}` in MB (10^6 bytes) | Engine-reported size after build |
| `layer_count` | Number of RootFS diff-IDs | `docker image inspect` |
| `time_to_ready_s` | Seconds from the `docker run -d` invocation until the first HTTP 2xx from `/health`, polled every 20 ms | `docker_ops.time_to_ready` |
| `warm_build_s` | Build time with a fully populated cache (nothing changed) | cache-probe procedure, first build |
| `incremental_rebuild_s` | Build time after exactly one file in the context is mutated | cache-probe procedure, second build |

`time_to_ready_s` is the user-perceived cold start: it includes container creation, namespace setup, interpreter start, application import and the first request. It deliberately does *not* include image pull; the image is already local.

### 3.4 Procedures

- **`build`**: for each trial, build the variant with `--no-cache`, record size and layers, optionally start it and measure readiness, then remove the container. The image is removed at the end of the run.
- **`cache_probe`**: for each trial, copy the fixture context to a fresh temporary directory, build once to warm the layer cache, append a comment line to the configured file (`cache_probe.mutate_file`), rebuild, and record the second build's time. Only the second build answers the research question; the first is recorded as `warm_build_s` for context.

## 4. Measurement protocol

1. **Environment capture** happens before the first trial and is stored as `environment.json` (host platform, CPU count, Docker client/server/BuildKit versions, storage driver, cgroup version, daemon CPU and memory limits, git commit and dirty flag, Docker-related environment variables).
2. **Warm-up rounds** (`design.warmup`, default 1) execute every variant once without recording. This pulls base images, primes the registry mirror and disk cache, and JIT-warms nothing (there is no JIT) but does bring the daemon to steady state.
3. **Recorded rounds** (`design.repetitions`, default 5 for builds, 7 for cache probes) follow.
4. **Block-randomised order.** Within every round each variant is measured exactly once, and the order of variants in that round is a fresh permutation drawn from a PRNG seeded with `design.seed`. Slow drift on the host (thermal throttling, background indexing, a backup starting) therefore affects all variants roughly equally instead of systematically penalising whichever variant happened to run last. The sequence is fully determined by the seed and is stored with the results.
5. **Append-only raw log.** Every trial is written to `raw.jsonl` the moment it finishes, with its round, position, timestamps, status and metrics. An interrupted run leaves a partial but valid dataset.
6. **Failures are data.** A trial that raises is recorded with `status: "error"` and the exception text. It is excluded from statistics but listed in the report. Nothing is retried silently.
7. **Cleanup.** Images tagged by the run are removed; containers are always removed (`--rm` plus an explicit `docker rm -f` in a `finally`).

Timing uses `time.perf_counter()`, a monotonic high-resolution clock unaffected by wall-clock adjustments.

## 5. Statistical analysis

All statistics are implemented in `research/harness/stats.py` on the Python standard library and are unit-tested against published table values.

### 5.1 Descriptive

For every metric and variant: `n`, mean, median, sample standard deviation, min, max, coefficient of variation, and a **95% confidence interval for the mean** using Student's t with `n-1` degrees of freedom. When `n >= 2` a seeded **percentile bootstrap** interval (2 000 resamples) is also reported; if the two intervals disagree markedly the sample is small or skewed and the median should be preferred.

### 5.2 Inferential (treatment vs baseline)

| Statistic | What it answers | Assumptions |
|-----------|-----------------|-------------|
| Δ and Δ% | How big is the difference in the metric's own units | none |
| Cohen's *d* | How big is the difference relative to the noise (pooled SD) | interval scale; interpreted with Cohen's thresholds 0.2 / 0.5 / 0.8 |
| Cliff's δ | Probability that a random treatment trial beats a random baseline trial, minus the reverse | ordinal only; robust to outliers |
| Welch's *t* (two-sided *p*) | Could a difference this large arise by chance if the means were equal | approximately normal residuals; unequal variances allowed |
| Permutation test (two-sided *p*) | Same question, with **no** distributional assumption | exchangeability under H0; exact enumeration when ≤ 5 000 splits, otherwise seeded Monte-Carlo with 5 000 draws |

### 5.3 Interpretation rules

- Effect size first, *p*-value second. With 5–7 repetitions a real but small effect can have *p* > 0.05, and a trivial effect can have *p* < 0.05 if variance is tiny. The report prints both so the reader is not misled by either.
- Non-overlapping 95% CIs are strong evidence of a difference. Overlapping CIs are **not** evidence of no difference.
- With ≤ 7 repetitions, prefer the permutation *p* over Welch's *p*.
- Multiple comparisons: an experiment with *k* treatment variants and *m* metrics performs *k × m* tests. No correction is applied automatically because the metrics are strongly correlated and the tests are confirmatory of a stated hypothesis, but readers applying a Bonferroni threshold of 0.05 / (*k × m*) should note which conclusions survive it. The experiment files keep *k* and *m* small for this reason.
- A "successful" experiment is one whose report can be read without the raw data and whose conclusion matches or clearly refutes the stated hypothesis. A null result is a result.

## 6. Reproducibility protocol

To reproduce a published run:

```bash
git checkout <commit recorded in environment.json>
pip install -r requirements.txt            # only stdlib is needed for the harness itself
python -m research.harness validate
python -m research.harness run exp01_base_image_footprint
python -m research.harness index
```

A reproduction should be reported with:

1. Its own `environment.json` (the harness writes it automatically).
2. The ratio of each treatment mean to the baseline mean, compared with the original ratio. **Ratios** are the quantity expected to transfer across machines; absolute seconds are not.
3. Whether each original hypothesis is still supported.

Things that are pinned: dependency versions in the fixture, the PRNG seed, the experiment definition (frozen as `experiment.json` inside every run directory), the harness version (git commit). Things that are **not** pinned and are known to move results: base-image digests (`python:3.12-slim` is a moving tag; record `docker image inspect --format {{.RepoDigests}}` if you need to freeze it), network latency to the registry and to PyPI, Docker Engine and BuildKit versions, and the host's storage driver.

## 7. Threats to validity

**Internal validity** (did the factor cause the effect?)
- *Drift*: mitigated by warm-up and block randomisation, not eliminated. Check `cv` in the report; > 25 % on a build-time metric means the host was noisy and the run should be repeated.
- *Cache leakage between variants*: BuildKit deduplicates identical layers across images. A variant sharing a base image with another may build faster because the other ran first. `--no-cache` disables layer reuse for the build's own instructions but base-image pulls are shared by design (this mirrors a developer machine). Set `design.prune_between_trials: true` for a fully cold builder cache at the cost of much longer runs and a network-bound measurement.
- *Registry and PyPI network*: cold builds download packages. On a fast connection the network term is small relative to the install step; on a slow one it dominates and inflates all variants equally. The cache-probe experiments largely remove this term.

**External validity** (does the result generalise?)
- Results are from one host and one Docker Engine version. macOS and Windows hosts run a Linux VM; Linux hosts do not. Absolute numbers differ by an order of magnitude across these; ratios are more stable but still not universal.
- The workload is a pure-Python service with pure-Python dependencies. Packages with compiled extensions change the Alpine (musl) picture dramatically and would strengthen the multi-stage result.
- `image_size_mb` is the Engine's view of the uncompressed layers. Registry transfer size (compressed) is typically 30–40 % smaller and differs per base.

**Construct validity** (are we measuring what we claim?)
- `time_to_ready_s` includes the harness's own polling interval (20 ms) and `docker run` client overhead, which are constant across variants and therefore cancel in comparisons but appear in absolute values.
- `layer_count` counts filesystem layers, not Dockerfile instructions; metadata instructions (`ENV`, `EXPOSE`, `CMD`) add no layer.

**Conclusion validity** (are the statistics sound?)
- Small *n*. The defaults (5 and 7) are a compromise between run time and power; they are adequate for the large effects these experiments target (*d* > 1) and inadequate for subtle ones. Raise `--repetitions` before claiming a small effect.
- Build times are right-skewed (occasional stalls). The median and Cliff's δ are less sensitive to this than the mean and Cohen's *d*; both are reported.

## 8. Adding an experiment

1. Put a Dockerfile per variant under `experiments/fixtures/<topic>/`. Keep the workload identical across variants unless the workload *is* the factor.
2. Write `experiments/expNN_<slug>.json` with `id == file stem`, a falsifiable `hypothesis`, a `baseline`, a `procedure`, and `design` values. Add a `tags` entry; `ci-smoke` marks experiments cheap enough for CI.
3. `python -m research.harness validate` must pass and `pytest research/tests` must still pass (the shipped-experiments test checks every fixture path).
4. Run it, read `report.md`, and only then decide whether the hypothesis text needs to be sharpened *for the next experiment*, never for this one.
5. Commit the run directory under `results/` and regenerate the index.

## 9. References

The statistical approach follows Georges, Buytaert and Eeckhout's guidance on rigorous performance evaluation, Mytkowicz et al.'s warnings on measurement bias, and Kalibera and Jones on repetition strategy; effect-size conventions follow Cohen and Cliff; the *t* machinery follows Numerical Recipes. Full citations are in [REFERENCES.md](REFERENCES.md) and `references.bib`.
