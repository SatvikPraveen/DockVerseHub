# Location: research/tests/test_stats.py
"""Unit tests for the stdlib statistics module.

Reference values come from standard t-tables and from hand computation,
so these tests also guard against silent regressions in the special
function code that everything else depends on.
"""

import math

import pytest

from research.harness import stats


@pytest.mark.parametrize(
    "p, df, expected",
    [
        (0.975, 1, 12.7062),
        (0.975, 2, 4.3027),
        (0.975, 4, 2.7764),
        (0.975, 10, 2.2281),
        (0.975, 30, 2.0423),
        (0.95, 10, 1.8125),
        (0.995, 10, 3.1693),
    ],
)
def test_t_ppf_matches_tables(p, df, expected):
    assert stats.t_ppf(p, df) == pytest.approx(expected, abs=1e-3)


def test_t_cdf_symmetry_and_limits():
    assert stats.t_cdf(0.0, 5) == pytest.approx(0.5)
    assert stats.t_cdf(2.0, 5) + stats.t_cdf(-2.0, 5) == pytest.approx(1.0)
    # Large df converges to the normal distribution
    assert stats.t_cdf(1.959964, 1e6) == pytest.approx(0.975, abs=1e-4)


def test_t_cdf_rejects_bad_df():
    with pytest.raises(ValueError):
        stats.t_cdf(1.0, 0)


def test_regularized_incomplete_beta_edges():
    assert stats.regularized_incomplete_beta(2, 3, 0.0) == 0.0
    assert stats.regularized_incomplete_beta(2, 3, 1.0) == 1.0
    # I_0.5(1,1) is the uniform CDF
    assert stats.regularized_incomplete_beta(1, 1, 0.5) == pytest.approx(0.5)


def test_summarize_basic():
    s = stats.summarize([10, 12, 11, 13, 12])
    assert s.n == 5
    assert s.mean == pytest.approx(11.6)
    assert s.median == 12
    assert s.stdev == pytest.approx(1.1401754, rel=1e-6)
    # t_{0.975,4} * sd / sqrt(5) = 2.7764 * 1.14018 / 2.23607 = 1.4157
    assert s.ci95_high - s.mean == pytest.approx(1.4157, abs=1e-3)
    assert s.ci95_low < s.mean < s.ci95_high
    assert s.cv == pytest.approx(s.stdev / s.mean)


def test_summarize_single_value_has_nan_ci():
    s = stats.summarize([5.0])
    assert s.stdev == 0.0
    assert math.isnan(s.ci95_low) and math.isnan(s.ci95_high)


def test_summarize_empty_raises():
    with pytest.raises(ValueError):
        stats.summarize([])


def test_bootstrap_is_deterministic_and_brackets_mean():
    xs = [3, 4, 5, 6, 7, 8, 9]
    a = stats.bootstrap_ci(xs, seed=1)
    b = stats.bootstrap_ci(xs, seed=1)
    c = stats.bootstrap_ci(xs, seed=2)
    assert a == b
    assert a != c
    assert a[0] <= 6.0 <= a[1]


def test_cohens_d_sign_and_magnitude():
    a = [1, 2, 3, 4, 5]
    b = [3, 4, 5, 6, 7]
    d = stats.cohens_d(a, b)
    # pooled sd = sqrt(2.5) ; diff = 2 -> d = 1.2649
    assert d == pytest.approx(1.2649, abs=1e-3)
    assert stats.cohens_d(b, a) == pytest.approx(-d)
    assert stats.interpret_d(d) == "large"
    assert stats.interpret_d(0.1) == "negligible"
    assert stats.interpret_d(float("nan")) == "n/a"


def test_cohens_d_degenerate():
    assert stats.cohens_d([1, 1, 1], [1, 1, 1]) == 0.0
    assert math.isinf(stats.cohens_d([1, 1, 1], [2, 2, 2]))
    assert math.isnan(stats.cohens_d([1], [2, 3]))


def test_cliffs_delta_extremes():
    assert stats.cliffs_delta([1, 2, 3], [4, 5, 6]) == 1.0
    assert stats.cliffs_delta([4, 5, 6], [1, 2, 3]) == -1.0
    assert stats.cliffs_delta([1, 2, 3], [1, 2, 3]) == 0.0


def test_welch_t_test_known_case():
    a = [10, 12, 11, 13, 12]
    b = [14, 15, 13, 16, 15]
    t, df, p = stats.welch_t_test(a, b)
    assert t == pytest.approx(4.1603, abs=1e-3)
    assert df == pytest.approx(8.0, abs=1e-6)
    assert p == pytest.approx(0.00316, abs=2e-4)


def test_welch_identical_samples():
    t, _, p = stats.welch_t_test([1, 1, 1], [1, 1, 1])
    assert t == 0.0 and p == 1.0


def test_permutation_test_exact_for_small_samples():
    # 5+5 -> C(10,5)=252 splits, enumerated exactly. Complete separation
    # of the groups gives the minimal two-sided p of 2/252.
    p = stats.permutation_test([1, 2, 3, 4, 5], [10, 11, 12, 13, 14])
    assert p == pytest.approx(2 / 252)


def test_permutation_test_monte_carlo_is_seeded():
    a = list(range(20))
    b = [x + 0.5 for x in range(20)]
    assert stats.permutation_test(a, b, iterations=500, seed=7) == stats.permutation_test(
        a, b, iterations=500, seed=7
    )


def test_compare_bundle():
    c = stats.compare([10, 12, 11, 13, 12], [14, 15, 13, 16, 15])
    assert c.delta == pytest.approx(3.0)
    assert c.delta_pct == pytest.approx(25.862, abs=1e-2)
    assert c.welch_p < 0.01
    assert c.permutation_p < 0.05
    assert c.cliffs_delta > 0.9
    d = c.to_dict()
    assert set(d) >= {"cohens_d", "welch_p", "permutation_p", "cliffs_delta"}
