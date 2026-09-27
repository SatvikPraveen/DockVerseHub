# Location: research/harness/stats.py
"""Descriptive and inferential statistics used by the research harness.

Everything here is implemented on the Python standard library so that
results can be reproduced without SciPy/NumPy. The Student-t machinery is
built on the regularised incomplete beta function (continued-fraction
evaluation, cf. Numerical Recipes 3rd ed., section 6.4) and is accurate to
roughly 1e-9, which is far beyond what benchmark data can justify.
"""

from __future__ import annotations

import math
import random
import statistics
from collections.abc import Sequence
from dataclasses import asdict, dataclass

# --------------------------------------------------------------------------- #
# Special functions
# --------------------------------------------------------------------------- #


def _betacf(a: float, b: float, x: float) -> float:
    """Continued fraction for the incomplete beta function (Lentz's method)."""
    max_iter = 300
    eps = 3.0e-14
    fpmin = 1.0e-300
    qab = a + b
    qap = a + 1.0
    qam = a - 1.0
    c = 1.0
    d = 1.0 - qab * x / qap
    if abs(d) < fpmin:
        d = fpmin
    d = 1.0 / d
    h = d
    for m in range(1, max_iter + 1):
        m2 = 2 * m
        aa = m * (b - m) * x / ((qam + m2) * (a + m2))
        d = 1.0 + aa * d
        if abs(d) < fpmin:
            d = fpmin
        c = 1.0 + aa / c
        if abs(c) < fpmin:
            c = fpmin
        d = 1.0 / d
        h *= d * c
        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))
        d = 1.0 + aa * d
        if abs(d) < fpmin:
            d = fpmin
        c = 1.0 + aa / c
        if abs(c) < fpmin:
            c = fpmin
        d = 1.0 / d
        delta = d * c
        h *= delta
        if abs(delta - 1.0) < eps:
            break
    return h


def regularized_incomplete_beta(a: float, b: float, x: float) -> float:
    """I_x(a, b) for 0 <= x <= 1."""
    if x <= 0.0:
        return 0.0
    if x >= 1.0:
        return 1.0
    lbeta = math.lgamma(a + b) - math.lgamma(a) - math.lgamma(b)
    front = math.exp(lbeta + a * math.log(x) + b * math.log(1.0 - x))
    if x < (a + 1.0) / (a + b + 2.0):
        return front * _betacf(a, b, x) / a
    return 1.0 - front * _betacf(b, a, 1.0 - x) / b


def t_cdf(t: float, df: float) -> float:
    """Cumulative distribution function of Student's t with `df` degrees of freedom."""
    if df <= 0:
        raise ValueError("degrees of freedom must be positive")
    x = df / (df + t * t)
    tail = 0.5 * regularized_incomplete_beta(df / 2.0, 0.5, x)
    return 1.0 - tail if t > 0 else tail


def t_ppf(p: float, df: float) -> float:
    """Quantile function (inverse CDF) of Student's t, by bisection."""
    if not 0.0 < p < 1.0:
        raise ValueError("p must be in (0, 1)")
    lo, hi = -1e3, 1e3
    for _ in range(200):
        mid = 0.5 * (lo + hi)
        if t_cdf(mid, df) < p:
            lo = mid
        else:
            hi = mid
        if hi - lo < 1e-10:
            break
    return 0.5 * (lo + hi)


# --------------------------------------------------------------------------- #
# Descriptive statistics
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class Summary:
    """Descriptive summary of one metric for one variant."""

    n: int
    mean: float
    median: float
    stdev: float
    minimum: float
    maximum: float
    cv: float  # coefficient of variation (stdev / mean), 0 when mean == 0
    ci95_low: float
    ci95_high: float

    def to_dict(self) -> dict:
        return asdict(self)


def summarize(values: Sequence[float], confidence: float = 0.95) -> Summary:
    """Mean, dispersion and a t-based confidence interval for the mean."""
    xs = [float(v) for v in values]
    if not xs:
        raise ValueError("cannot summarise an empty sample")
    n = len(xs)
    mean = statistics.fmean(xs)
    sd = statistics.stdev(xs) if n > 1 else 0.0
    if n > 1:
        half = t_ppf(0.5 + confidence / 2.0, n - 1) * sd / math.sqrt(n)
    else:
        half = float("nan")
    return Summary(
        n=n,
        mean=mean,
        median=statistics.median(xs),
        stdev=sd,
        minimum=min(xs),
        maximum=max(xs),
        cv=(sd / mean) if mean else 0.0,
        ci95_low=mean - half,
        ci95_high=mean + half,
    )


def bootstrap_ci(
    values: Sequence[float],
    statistic=statistics.fmean,
    resamples: int = 2000,
    confidence: float = 0.95,
    seed: int = 42,
) -> tuple[float, float]:
    """Percentile bootstrap interval. Deterministic for a given seed."""
    xs = [float(v) for v in values]
    if not xs:
        raise ValueError("cannot bootstrap an empty sample")
    rng = random.Random(seed)
    n = len(xs)
    boots = sorted(statistic([xs[rng.randrange(n)] for _ in range(n)]) for _ in range(resamples))
    alpha = (1.0 - confidence) / 2.0
    lo = boots[max(0, int(math.floor(alpha * resamples)) - 1)]
    hi = boots[min(resamples - 1, int(math.ceil((1.0 - alpha) * resamples)) - 1)]
    return lo, hi


# --------------------------------------------------------------------------- #
# Two-sample comparisons
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class Comparison:
    """Treatment vs baseline for one metric."""

    baseline_mean: float
    treatment_mean: float
    delta: float  # treatment - baseline
    delta_pct: float  # 100 * delta / baseline (nan if baseline == 0)
    cohens_d: float
    cliffs_delta: float
    welch_t: float
    welch_df: float
    welch_p: float  # two-sided
    permutation_p: float  # two-sided, Monte-Carlo unless exact is small enough

    def to_dict(self) -> dict:
        return asdict(self)


def cohens_d(a: Sequence[float], b: Sequence[float]) -> float:
    """Standardised mean difference (b - a) with pooled standard deviation."""
    na, nb = len(a), len(b)
    if na < 2 or nb < 2:
        return float("nan")
    va = statistics.variance(a)
    vb = statistics.variance(b)
    pooled = math.sqrt(((na - 1) * va + (nb - 1) * vb) / (na + nb - 2))
    if pooled == 0.0:
        return (
            0.0
            if statistics.fmean(a) == statistics.fmean(b)
            else math.copysign(float("inf"), statistics.fmean(b) - statistics.fmean(a))
        )
    return (statistics.fmean(b) - statistics.fmean(a)) / pooled


def cliffs_delta(a: Sequence[float], b: Sequence[float]) -> float:
    """Non-parametric effect size in [-1, 1]: P(b > a) - P(b < a)."""
    if not a or not b:
        return float("nan")
    more = sum(1 for x in a for y in b if y > x)
    less = sum(1 for x in a for y in b if y < x)
    return (more - less) / (len(a) * len(b))


def welch_t_test(a: Sequence[float], b: Sequence[float]) -> tuple[float, float, float]:
    """Welch's unequal-variance t-test. Returns (t, df, two-sided p)."""
    na, nb = len(a), len(b)
    if na < 2 or nb < 2:
        return float("nan"), float("nan"), float("nan")
    ma, mb = statistics.fmean(a), statistics.fmean(b)
    va, vb = statistics.variance(a), statistics.variance(b)
    se2 = va / na + vb / nb
    if se2 == 0.0:
        return (
            (0.0, float(na + nb - 2), 1.0) if ma == mb else (float("inf"), float(na + nb - 2), 0.0)
        )
    t = (mb - ma) / math.sqrt(se2)
    df = se2 * se2 / ((va / na) ** 2 / (na - 1) + (vb / nb) ** 2 / (nb - 1))
    p = 2.0 * (1.0 - t_cdf(abs(t), df))
    return t, df, p


def permutation_test(
    a: Sequence[float], b: Sequence[float], iterations: int = 5000, seed: int = 42
) -> float:
    """Two-sided permutation test on the difference of means.

    Uses full enumeration when the number of distinct splits is small
    (<= iterations), otherwise a seeded Monte-Carlo approximation.
    """
    if not a or not b:
        return float("nan")
    pooled = [float(x) for x in a] + [float(x) for x in b]
    na = len(a)
    observed = abs(statistics.fmean(pooled[na:]) - statistics.fmean(pooled[:na]))
    total = math.comb(len(pooled), na)
    if total <= iterations:
        from itertools import combinations

        idx_all = range(len(pooled))
        count = 0
        for combo in combinations(idx_all, na):
            chosen = set(combo)
            ga = [pooled[i] for i in chosen]
            gb = [pooled[i] for i in idx_all if i not in chosen]
            if abs(statistics.fmean(gb) - statistics.fmean(ga)) >= observed - 1e-12:
                count += 1
        return count / total
    rng = random.Random(seed)
    count = 0
    for _ in range(iterations):
        rng.shuffle(pooled)
        if abs(statistics.fmean(pooled[na:]) - statistics.fmean(pooled[:na])) >= observed - 1e-12:
            count += 1
    return (count + 1) / (iterations + 1)


def compare(baseline: Sequence[float], treatment: Sequence[float], seed: int = 42) -> Comparison:
    """Full comparison bundle of treatment against baseline."""
    a = [float(v) for v in baseline]
    b = [float(v) for v in treatment]
    ma = statistics.fmean(a)
    mb = statistics.fmean(b)
    t, df, p = welch_t_test(a, b)
    return Comparison(
        baseline_mean=ma,
        treatment_mean=mb,
        delta=mb - ma,
        delta_pct=(100.0 * (mb - ma) / ma) if ma else float("nan"),
        cohens_d=cohens_d(a, b),
        cliffs_delta=cliffs_delta(a, b),
        welch_t=t,
        welch_df=df,
        welch_p=p,
        permutation_p=permutation_test(a, b, seed=seed),
    )


def interpret_d(d: float) -> str:
    """Cohen (1988) rules of thumb for |d|."""
    if math.isnan(d):
        return "n/a"
    m = abs(d)
    if m < 0.2:
        return "negligible"
    if m < 0.5:
        return "small"
    if m < 0.8:
        return "medium"
    return "large"
