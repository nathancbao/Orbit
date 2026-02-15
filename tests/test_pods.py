"""Tests for OrbitServer/pods/math.py — Vibe Match Algorithm.

These tests cover the pure scoring functions (Phase A) and quiz-based
vibe check scoring.  Signal lifecycle tests are in test_signals.py.
"""

import math
from unittest.mock import patch, MagicMock

from OrbitServer.signals.math import (
    interest_score,
    vibe_score,
    vibe_check_score,
    mbti_compatibility_bonus,
    weighted_match_score,
    PERSONALITY_KEYS,
    VIBE_CHECK_KEYS,
    MBTI_BEST_FRIENDS,
)


# ── Helpers ──────────────────────────────────────────────────────────────────

def _make_profile(user_id, name, interests=None, personality=None, vibe_check=None):
    """Build a profile dict matching the Datastore shape."""
    profile = {
        'user_id': user_id,
        'name': name,
        'interests': interests or [],
        'personality': personality or {
            'introvert_extrovert': 0.5,
            'spontaneous_planner': 0.5,
            'active_relaxed': 0.5,
        },
        'social_preferences': {
            'group_size': 'Small groups (3-5)',
            'meeting_frequency': 'Weekly',
            'preferred_times': [],
        },
        'friendship_goals': [],
    }
    if vibe_check is not None:
        profile['vibe_check'] = vibe_check
    return profile


def _make_vibe_check(values=None, mbti_type='ENFP'):
    """Build a vibe_check dict with all 8 dimensions."""
    defaults = {k: 0.5 for k in VIBE_CHECK_KEYS}
    defaults['mbti_type'] = mbti_type
    if values:
        defaults.update(values)
    return defaults


# ═══════════════════════════════════════════════════════════════════════════
#  PHASE A — Vibe Math
# ═══════════════════════════════════════════════════════════════════════════

class TestInterestScore:
    def test_identical_interests(self):
        assert interest_score(['a', 'b', 'c'], ['a', 'b', 'c']) == 1.0

    def test_no_overlap(self):
        assert interest_score(['a', 'b'], ['c', 'd']) == 0.0

    def test_partial_overlap(self):
        # {a, b, c} ∩ {b, c, d} = {b, c}  →  2 / 4 = 0.5
        assert interest_score(['a', 'b', 'c'], ['b', 'c', 'd']) == 0.5

    def test_both_empty(self):
        assert interest_score([], []) == 0.0

    def test_one_empty(self):
        assert interest_score(['a'], []) == 0.0

    def test_none_inputs(self):
        assert interest_score(None, None) == 0.0
        assert interest_score(None, ['a']) == 0.0

    def test_duplicates_ignored(self):
        # Sets deduplicate: {a, b} ∩ {a, b} = {a, b}  →  1.0
        assert interest_score(['a', 'a', 'b'], ['a', 'b', 'b']) == 1.0


class TestVibeScore:
    def test_identical_personalities(self):
        p = {'introvert_extrovert': 0.8, 'spontaneous_planner': 0.3, 'active_relaxed': 0.6}
        assert vibe_score(p, p) == 1.0

    def test_opposite_personalities(self):
        p_a = {'introvert_extrovert': 0.0, 'spontaneous_planner': 0.0, 'active_relaxed': 0.0}
        p_b = {'introvert_extrovert': 1.0, 'spontaneous_planner': 1.0, 'active_relaxed': 1.0}
        assert vibe_score(p_a, p_b) == 0.0

    def test_missing_personality(self):
        assert vibe_score(None, {'introvert_extrovert': 0.5}) == 0.0
        assert vibe_score({'introvert_extrovert': 0.5}, None) == 0.0

    def test_score_between_zero_and_one(self):
        p_a = {'introvert_extrovert': 0.2, 'spontaneous_planner': 0.7, 'active_relaxed': 0.4}
        p_b = {'introvert_extrovert': 0.6, 'spontaneous_planner': 0.3, 'active_relaxed': 0.8}
        score = vibe_score(p_a, p_b)
        assert 0.0 < score < 1.0

    def test_symmetric(self):
        p_a = {'introvert_extrovert': 0.1, 'spontaneous_planner': 0.9, 'active_relaxed': 0.5}
        p_b = {'introvert_extrovert': 0.7, 'spontaneous_planner': 0.2, 'active_relaxed': 0.8}
        assert vibe_score(p_a, p_b) == vibe_score(p_b, p_a)

    def test_defaults_to_midpoint_for_missing_keys(self):
        p_a = {'introvert_extrovert': 0.5}
        p_b = {'introvert_extrovert': 0.5}
        # Both default to 0.5 on missing keys → distance = 0 → score = 1.0
        assert vibe_score(p_a, p_b) == 1.0


class TestWeightedMatchScore:
    def test_perfect_match(self):
        p = _make_profile(1, 'A', ['x', 'y'], {
            'introvert_extrovert': 0.5,
            'spontaneous_planner': 0.5,
            'active_relaxed': 0.5,
        })
        assert weighted_match_score(p, p) == 1.0

    def test_no_match(self):
        p_a = _make_profile(1, 'A', ['x'], {
            'introvert_extrovert': 0.0,
            'spontaneous_planner': 0.0,
            'active_relaxed': 0.0,
        })
        p_b = _make_profile(2, 'B', ['y'], {
            'introvert_extrovert': 1.0,
            'spontaneous_planner': 1.0,
            'active_relaxed': 1.0,
        })
        assert weighted_match_score(p_a, p_b) == 0.0

    def test_weighting_40_60(self):
        # Same personality (vibe=1.0), no interest overlap (interest=0.0)
        p_a = _make_profile(1, 'A', ['x'])
        p_b = _make_profile(2, 'B', ['y'])
        score = weighted_match_score(p_a, p_b)
        # 0.40 * 0.0 + 0.60 * 1.0 = 0.60
        assert score == 0.6

    def test_symmetric(self):
        p_a = _make_profile(1, 'A', ['a', 'b'], {
            'introvert_extrovert': 0.2,
            'spontaneous_planner': 0.8,
            'active_relaxed': 0.5,
        })
        p_b = _make_profile(2, 'B', ['b', 'c'], {
            'introvert_extrovert': 0.7,
            'spontaneous_planner': 0.3,
            'active_relaxed': 0.9,
        })
        assert weighted_match_score(p_a, p_b) == weighted_match_score(p_b, p_a)


# ═══════════════════════════════════════════════════════════════════════════
#  Vibe Check (Quiz-based 8-dim scoring)
# ═══════════════════════════════════════════════════════════════════════════

class TestVibeCheckScore:
    def test_identical_vibe_check(self):
        vc = _make_vibe_check()
        assert vibe_check_score(vc, vc) == 1.0

    def test_opposite_vibe_check(self):
        vc_a = {k: 0.0 for k in VIBE_CHECK_KEYS}
        vc_b = {k: 1.0 for k in VIBE_CHECK_KEYS}
        assert vibe_check_score(vc_a, vc_b) == 0.0

    def test_missing_vibe_check(self):
        vc = _make_vibe_check()
        assert vibe_check_score(None, vc) == 0.0
        assert vibe_check_score(vc, None) == 0.0

    def test_score_between_zero_and_one(self):
        vc_a = _make_vibe_check({'introvert_extrovert': 0.2, 'adventurous_cautious': 0.8})
        vc_b = _make_vibe_check({'introvert_extrovert': 0.7, 'adventurous_cautious': 0.3})
        score = vibe_check_score(vc_a, vc_b)
        assert 0.0 < score < 1.0

    def test_symmetric(self):
        vc_a = _make_vibe_check({'introvert_extrovert': 0.1, 'sensing_intuition': 0.9})
        vc_b = _make_vibe_check({'introvert_extrovert': 0.8, 'sensing_intuition': 0.2})
        assert vibe_check_score(vc_a, vc_b) == vibe_check_score(vc_b, vc_a)

    def test_defaults_to_midpoint(self):
        vc_a = {'introvert_extrovert': 0.5}
        vc_b = {'introvert_extrovert': 0.5}
        assert vibe_check_score(vc_a, vc_b) == 1.0


class TestMbtiCompatibility:
    def test_best_friend_pair_infj_enfp(self):
        assert mbti_compatibility_bonus('INFJ', 'ENFP') == 0.10

    def test_best_friend_pair_enfp_infj(self):
        # Symmetric: ENFP has INFJ in best-friend list too
        assert mbti_compatibility_bonus('ENFP', 'INFJ') == 0.10

    def test_same_type_in_best_friends(self):
        # ENFP+ENFP is in ENFP's best-friend list → 0.10
        assert mbti_compatibility_bonus('ENFP', 'ENFP') == 0.10

    def test_same_type_not_in_best_friends(self):
        # ESTP+ESTP: ESTP's best friends are ['ESTP', 'ESFP'], so same type IS listed → 0.10
        assert mbti_compatibility_bonus('ESTP', 'ESTP') == 0.10

    def test_no_match(self):
        # ISTJ+ESFP: not in each other's best-friend lists
        assert mbti_compatibility_bonus('ISTJ', 'ESFP') == 0.0

    def test_case_insensitive(self):
        assert mbti_compatibility_bonus('infj', 'enfp') == 0.10

    def test_none_inputs(self):
        assert mbti_compatibility_bonus(None, 'ENFP') == 0.0
        assert mbti_compatibility_bonus('ENFP', None) == 0.0
        assert mbti_compatibility_bonus(None, None) == 0.0

    def test_empty_string(self):
        assert mbti_compatibility_bonus('', 'ENFP') == 0.0


class TestWeightedMatchWithVibeCheck:
    def test_prefers_vibe_check_over_sliders(self):
        """When both profiles have vibe_check, it should be used instead of sliders."""
        vc = _make_vibe_check(mbti_type='ENFP')
        p_a = _make_profile(1, 'A', ['x'], vibe_check=vc)
        p_b = _make_profile(2, 'B', ['x'], vibe_check=vc)
        score = weighted_match_score(p_a, p_b)
        # Same vibe_check + same interest + ENFP+ENFP bonus (0.10)
        # 0.40 * 1.0 + 0.60 * 1.0 + 0.10 = 1.10 → capped at 1.0
        assert score == 1.0

    def test_falls_back_to_sliders(self):
        """When only one profile has vibe_check, fall back to sliders."""
        vc = _make_vibe_check()
        p_a = _make_profile(1, 'A', ['x'], vibe_check=vc)
        p_b = _make_profile(2, 'B', ['x'])  # No vibe_check
        score = weighted_match_score(p_a, p_b)
        # Falls back to slider personality: both default 0.5 → vibe=1.0
        # 0.40 * 1.0 + 0.60 * 1.0 = 1.0, no MBTI bonus
        assert score == 1.0

    def test_old_profiles_still_work(self):
        """Old profiles without vibe_check still match using sliders."""
        p_a = _make_profile(1, 'A', ['x', 'y'])
        p_b = _make_profile(2, 'B', ['x', 'y'])
        score = weighted_match_score(p_a, p_b)
        assert score == 1.0

    def test_mbti_bonus_additive(self):
        """MBTI bonus adds to the raw score."""
        vc_a = _make_vibe_check({'introvert_extrovert': 0.3}, mbti_type='INFJ')
        vc_b = _make_vibe_check({'introvert_extrovert': 0.3}, mbti_type='ENFP')
        p_a = _make_profile(1, 'A', [], vibe_check=vc_a)
        p_b = _make_profile(2, 'B', [], vibe_check=vc_b)
        score = weighted_match_score(p_a, p_b)
        # Interests: both empty → 0.0
        # Vibe check: identical → 1.0
        # 0.40 * 0.0 + 0.60 * 1.0 + 0.10 = 0.70
        assert score == 0.7

    def test_score_capped_at_one(self):
        """Score should never exceed 1.0 even with MBTI bonus."""
        vc_a = _make_vibe_check(mbti_type='INFJ')
        vc_b = _make_vibe_check(mbti_type='ENFP')
        p_a = _make_profile(1, 'A', ['x', 'y'], vibe_check=vc_a)
        p_b = _make_profile(2, 'B', ['x', 'y'], vibe_check=vc_b)
        score = weighted_match_score(p_a, p_b)
        assert score <= 1.0
