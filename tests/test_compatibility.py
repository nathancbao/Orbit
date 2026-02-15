"""Tests for OrbitApp/Orbit/Features/AI/compatibility.py — dynamic weight compatibility scoring."""

import math

from OrbitApp.Orbit.Features.AI.compatibility import (
    _conviction,
    _get_weights,
    _W_BASE,
    _W_VIBE,
    _VIBE_CHECK_DIMS,
    interest_score,
    personality_score,
    social_score,
    goals_score,
    compatibility,
)


# ── Helpers ──────────────────────────────────────────────────────────────────

def _make_vibe_check(overrides=None):
    """Build a vibe_check dict with all 8 dimensions defaulting to 0.5."""
    vc = {d: 0.5 for d in _VIBE_CHECK_DIMS}
    if overrides:
        vc.update(overrides)
    return vc


def _make_profile(interests=None, personality=None, social=None,
                  goals=None, vibe_check=None):
    """Build a minimal profile dict for compatibility()."""
    p = {
        "interests": interests or [],
        "personality": personality or {
            "introvert_extrovert": 0.5,
            "spontaneous_planner": 0.5,
            "active_relaxed": 0.5,
        },
        "social_preferences": social or {
            "group_size": "Small groups (3-5)",
            "meeting_frequency": "Weekly",
            "preferred_times": [],
        },
        "friendship_goals": goals or [],
    }
    if vibe_check is not None:
        p["vibe_check"] = vibe_check
    return p


# ═══════════════════════════════════════════════════════════════════════════
#  _conviction
# ═══════════════════════════════════════════════════════════════════════════

class TestConviction:
    def test_all_neutral_returns_zero(self):
        vc = _make_vibe_check()  # all 0.5
        assert _conviction(vc) == 0.0

    def test_all_extreme_returns_one(self):
        # Every dimension at 0.0 or 1.0 → deviation = 0.5 each → avg/0.5 = 1.0
        vc = {d: (0.0 if i % 2 == 0 else 1.0)
              for i, d in enumerate(_VIBE_CHECK_DIMS)}
        assert _conviction(vc) == 1.0

    def test_mixed_values(self):
        vc = _make_vibe_check({"introvert_extrovert": 0.0, "thinking_feeling": 1.0})
        # 2 extreme dims (dev=0.5 each) + 6 neutral dims (dev=0.0 each)
        # avg dev = (0.5*2) / 8 = 0.125, normalised = 0.125 / 0.5 = 0.25
        assert abs(_conviction(vc) - 0.25) < 1e-9

    def test_missing_keys_default_to_neutral(self):
        # Partial dict — missing keys treated as 0.5 (neutral)
        vc = {"introvert_extrovert": 0.0}
        # 1 dim at 0.0 (dev=0.5), 7 missing → dev=0.0 each
        expected = (0.5 / 8) / 0.5
        assert abs(_conviction(vc) - expected) < 1e-9

    def test_symmetric_around_midpoint(self):
        # 0.3 and 0.7 are equidistant from 0.5
        vc_low = _make_vibe_check({"introvert_extrovert": 0.3})
        vc_high = _make_vibe_check({"introvert_extrovert": 0.7})
        assert abs(_conviction(vc_low) - _conviction(vc_high)) < 1e-9


# ═══════════════════════════════════════════════════════════════════════════
#  _get_weights
# ═══════════════════════════════════════════════════════════════════════════

class TestGetWeights:
    def test_no_quiz_data_returns_base(self):
        a = _make_profile()
        b = _make_profile()
        assert _get_weights(a, b) == _W_BASE

    def test_only_one_has_quiz_returns_base(self):
        a = _make_profile(vibe_check=_make_vibe_check())
        b = _make_profile()
        assert _get_weights(a, b) == _W_BASE

    def test_both_neutral_quiz_returns_base(self):
        # Both have quiz but all answers are 0.5 → conviction=0 → blend=0
        vc = _make_vibe_check()
        a = _make_profile(vibe_check=vc)
        b = _make_profile(vibe_check=vc)
        w = _get_weights(a, b)
        for k in _W_BASE:
            assert abs(w[k] - _W_BASE[k]) < 1e-9

    def test_both_extreme_quiz_returns_vibe_weights(self):
        vc = {d: (0.0 if i % 2 == 0 else 1.0)
              for i, d in enumerate(_VIBE_CHECK_DIMS)}
        a = _make_profile(vibe_check=vc)
        b = _make_profile(vibe_check=vc)
        w = _get_weights(a, b)
        for k in _W_VIBE:
            assert abs(w[k] - _W_VIBE[k]) < 1e-9

    def test_weights_always_sum_to_one(self):
        # Varying conviction levels
        for val in [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0]:
            vc = {d: val for d in _VIBE_CHECK_DIMS}
            a = _make_profile(vibe_check=vc)
            b = _make_profile(vibe_check=vc)
            w = _get_weights(a, b)
            assert abs(sum(w.values()) - 1.0) < 1e-9

    def test_personality_weight_increases_with_conviction(self):
        vc_mild = _make_vibe_check({"introvert_extrovert": 0.3})
        vc_strong = {d: 0.0 for d in _VIBE_CHECK_DIMS}

        w_mild = _get_weights(
            _make_profile(vibe_check=vc_mild),
            _make_profile(vibe_check=vc_mild),
        )
        w_strong = _get_weights(
            _make_profile(vibe_check=vc_strong),
            _make_profile(vibe_check=vc_strong),
        )
        assert w_strong["personality"] > w_mild["personality"]

    def test_asymmetric_conviction_blends(self):
        # One decisive, one neutral → average conviction → partial blend
        vc_extreme = {d: 0.0 for d in _VIBE_CHECK_DIMS}
        vc_neutral = _make_vibe_check()
        a = _make_profile(vibe_check=vc_extreme)
        b = _make_profile(vibe_check=vc_neutral)
        w = _get_weights(a, b)
        # Average conviction = (1.0 + 0.0) / 2 = 0.5
        # So weights should be midpoint between base and vibe
        for k in _W_BASE:
            expected = _W_BASE[k] + 0.5 * (_W_VIBE[k] - _W_BASE[k])
            assert abs(w[k] - expected) < 1e-9


# ═══════════════════════════════════════════════════════════════════════════
#  personality_score (3-dim fallback vs 8-dim vibe check)
# ═══════════════════════════════════════════════════════════════════════════

class TestPersonalityScore:
    def test_identical_basic_personality(self):
        p = {"introvert_extrovert": 0.5, "spontaneous_planner": 0.5, "active_relaxed": 0.5}
        assert personality_score(p, p) == 1.0

    def test_opposite_basic_personality(self):
        a = {"introvert_extrovert": 0.0, "spontaneous_planner": 0.0, "active_relaxed": 0.0}
        b = {"introvert_extrovert": 1.0, "spontaneous_planner": 1.0, "active_relaxed": 1.0}
        assert abs(personality_score(a, b)) < 1e-9

    def test_none_falls_back_to_defaults(self):
        # Both None → both default to 0.5 on all → distance=0 → score=1.0
        assert personality_score(None, None) == 1.0

    def test_symmetric(self):
        a = {"introvert_extrovert": 0.2, "spontaneous_planner": 0.8, "active_relaxed": 0.5}
        b = {"introvert_extrovert": 0.7, "spontaneous_planner": 0.3, "active_relaxed": 0.9}
        assert personality_score(a, b) == personality_score(b, a)

    def test_uses_8_dims_when_both_have_vibe_check(self):
        vc_a = _make_vibe_check({"adventurous_cautious": 0.0})
        vc_b = _make_vibe_check({"adventurous_cautious": 1.0})
        # Basic personality is identical (both default 0.5 on 3 traits)
        basic = {"introvert_extrovert": 0.5, "spontaneous_planner": 0.5, "active_relaxed": 0.5}

        score_basic = personality_score(basic, basic)
        score_vibe = personality_score(basic, basic,
                                       vibe_check_a=vc_a, vibe_check_b=vc_b)

        # Basic gives 1.0 (identical), vibe check < 1.0 (adventurous differs)
        assert score_basic == 1.0
        assert score_vibe < 1.0

    def test_falls_back_when_one_missing_vibe_check(self):
        vc = _make_vibe_check()
        basic = {"introvert_extrovert": 0.5, "spontaneous_planner": 0.5, "active_relaxed": 0.5}
        # One vibe_check missing → should use 3-dim basic scoring
        score = personality_score(basic, basic, vibe_check_a=vc, vibe_check_b=None)
        assert score == 1.0

    def test_identical_vibe_check_scores_one(self):
        vc = _make_vibe_check({"introvert_extrovert": 0.2, "thinking_feeling": 0.8})
        assert personality_score(None, None, vibe_check_a=vc, vibe_check_b=vc) == 1.0

    def test_opposite_vibe_check_scores_zero(self):
        vc_a = {d: 0.0 for d in _VIBE_CHECK_DIMS}
        vc_b = {d: 1.0 for d in _VIBE_CHECK_DIMS}
        score = personality_score(None, None, vibe_check_a=vc_a, vibe_check_b=vc_b)
        assert abs(score) < 1e-9

    def test_8_dim_max_distance_is_sqrt8(self):
        # Verify the normalization uses sqrt(8) for 8 dimensions
        vc_a = {d: 0.0 for d in _VIBE_CHECK_DIMS}
        vc_b = {d: 1.0 for d in _VIBE_CHECK_DIMS}
        # dist = sqrt(8), max_dist = sqrt(8) → score = 0.0
        score = personality_score(None, None, vibe_check_a=vc_a, vibe_check_b=vc_b)
        assert abs(score) < 1e-9


# ═══════════════════════════════════════════════════════════════════════════
#  compatibility (end-to-end with dynamic weights)
# ═══════════════════════════════════════════════════════════════════════════

class TestCompatibility:
    def test_identical_profiles_score_one(self):
        p = _make_profile(
            interests=["hiking", "music"],
            goals=["study buddies"],
        )
        assert abs(compatibility(p, p) - 1.0) < 1e-9

    def test_score_between_zero_and_one(self):
        a = _make_profile(interests=["hiking"], goals=["study buddies"])
        b = _make_profile(interests=["cooking"], goals=["gym partner"])
        score = compatibility(a, b)
        assert 0.0 <= score <= 1.0

    def test_symmetric(self):
        a = _make_profile(
            interests=["a", "b"],
            personality={"introvert_extrovert": 0.2, "spontaneous_planner": 0.8, "active_relaxed": 0.5},
        )
        b = _make_profile(
            interests=["b", "c"],
            personality={"introvert_extrovert": 0.7, "spontaneous_planner": 0.3, "active_relaxed": 0.9},
        )
        assert abs(compatibility(a, b) - compatibility(b, a)) < 1e-9

    def test_no_quiz_uses_base_weights(self):
        # With no vibe check, personality is 30% of score
        # Identical profiles → all sub-scores = 1.0 → total = 1.0
        a = _make_profile(interests=["x"])
        b = _make_profile(interests=["x"])
        assert abs(compatibility(a, b) - 1.0) < 1e-9

    def test_vibe_check_shifts_personality_weight(self):
        """When quiz data exists and is decisive, personality weight goes up.
        Two profiles with different interests but similar quiz results should
        score higher than without quiz data (personality gets more weight)."""
        personality = {"introvert_extrovert": 0.5, "spontaneous_planner": 0.5, "active_relaxed": 0.5}
        vc = {d: 0.0 for d in _VIBE_CHECK_DIMS}  # extreme → full conviction

        # Profiles: no interest overlap, identical personality/vibe_check
        a_no_quiz = _make_profile(interests=["hiking"], personality=personality)
        b_no_quiz = _make_profile(interests=["cooking"], personality=personality)

        a_quiz = _make_profile(interests=["hiking"], personality=personality, vibe_check=vc)
        b_quiz = _make_profile(interests=["cooking"], personality=personality, vibe_check=vc)

        score_no_quiz = compatibility(a_no_quiz, b_no_quiz)
        score_quiz = compatibility(a_quiz, b_quiz)

        # With quiz: personality weight ↑ (0.30→0.40), interest weight ↓ (0.30→0.25)
        # Interest=0.0 hurts less, personality=1.0 helps more → higher overall
        assert score_quiz > score_no_quiz

    def test_neutral_quiz_does_not_shift_weights(self):
        """All-neutral quiz answers should produce same result as no quiz."""
        vc_neutral = _make_vibe_check()  # all 0.5
        personality = {"introvert_extrovert": 0.5, "spontaneous_planner": 0.5, "active_relaxed": 0.5}

        a_no_quiz = _make_profile(interests=["x", "y"], personality=personality)
        b_no_quiz = _make_profile(interests=["x", "z"], personality=personality)

        a_quiz = _make_profile(interests=["x", "y"], personality=personality, vibe_check=vc_neutral)
        b_quiz = _make_profile(interests=["x", "z"], personality=personality, vibe_check=vc_neutral)

        score_no_quiz = compatibility(a_no_quiz, b_no_quiz)
        score_quiz = compatibility(a_quiz, b_quiz)

        # Neutral quiz → conviction=0 → weights unchanged, and vibe check
        # values are all 0.5 (same as basic personality) → same personality score
        assert abs(score_no_quiz - score_quiz) < 1e-9

    def test_one_sided_quiz_uses_base_weights(self):
        """If only one user has quiz data, base weights should be used."""
        vc = {d: 0.0 for d in _VIBE_CHECK_DIMS}
        a = _make_profile(interests=["x"], vibe_check=vc)
        b = _make_profile(interests=["x"])

        score = compatibility(a, b)
        # Both have identical defaults → all sub-scores = 1.0 → total = 1.0
        assert abs(score - 1.0) < 1e-9

    def test_empty_profiles(self):
        a = _make_profile()
        b = _make_profile()
        # Empty interests → 0.0, default personality → 1.0,
        # identical social → 1.0, empty goals → 1.0
        # 0.30*0.0 + 0.30*1.0 + 0.20*1.0 + 0.20*1.0 = 0.70
        assert abs(compatibility(a, b) - 0.70) < 1e-9

    def test_decisive_quiz_changes_weight_distribution(self):
        """Verify the exact weight shift with fully decisive quiz answers."""
        vc = {d: 0.0 for d in _VIBE_CHECK_DIMS}  # conviction = 1.0

        # Build profiles where only interests differ, everything else matches
        a = _make_profile(interests=[], vibe_check=vc, goals=["study buddies"])
        b = _make_profile(interests=[], vibe_check=vc, goals=["study buddies"])

        score = compatibility(a, b)
        # interest=0.0, personality=1.0 (identical vc), social=1.0, goals=1.0
        # Vibe weights: 0.25*0 + 0.40*1 + 0.20*1 + 0.15*1 = 0.75
        assert abs(score - 0.75) < 1e-9

        # Without quiz: 0.30*0 + 0.30*1 + 0.20*1 + 0.20*1 = 0.70
        a_no = _make_profile(interests=[], goals=["study buddies"])
        b_no = _make_profile(interests=[], goals=["study buddies"])
        assert abs(compatibility(a_no, b_no) - 0.70) < 1e-9
