"""Tests for ML integration of survey data — behavioral decay and LightFM scoring."""


class TestEnjoymentInBehavioralDecay:
    """Verify enjoyment_rating multiplier affects behavioral scoring."""

    def test_action_score_default_no_enjoyment(self):
        from OrbitServer.services.ai_suggestion_service import _action_score
        # joined + attended but no enjoyment rating -> base + bonus
        score = _action_score('joined', True, None)
        assert score == 0.8 + 0.2  # 1.0

    def test_action_score_high_enjoyment_boosts(self):
        from OrbitServer.services.ai_suggestion_service import _action_score
        # joined + attended + 5-star enjoyment -> (0.8 + 0.2) * 1.6
        score = _action_score('joined', True, 5)
        assert abs(score - 1.6) < 1e-9

    def test_action_score_low_enjoyment_dampens(self):
        from OrbitServer.services.ai_suggestion_service import _action_score
        # joined + attended + 1-star enjoyment -> (0.8 + 0.2) * 0.3
        score = _action_score('joined', True, 1)
        assert abs(score - 0.3) < 1e-9

    def test_action_score_medium_enjoyment_neutral(self):
        from OrbitServer.services.ai_suggestion_service import _action_score
        # joined + attended + 3-star -> (0.8 + 0.2) * 1.0 = 1.0
        score = _action_score('joined', True, 3)
        assert abs(score - 1.0) < 1e-9

    def test_action_score_enjoyment_only_applies_to_joined(self):
        from OrbitServer.services.ai_suggestion_service import _action_score
        # browsed with enjoyment (shouldn't happen, but shouldn't crash)
        score = _action_score('browsed', None, 5)
        assert score == 0.3  # unchanged, enjoyment only applies to 'joined'

    def test_action_score_no_attended_with_enjoyment(self):
        from OrbitServer.services.ai_suggestion_service import _action_score
        # joined but attended=False, with enjoyment=4 -> 0.8 * 1.3
        score = _action_score('joined', False, 4)
        assert abs(score - 0.8 * 1.3) < 1e-9

    def test_behavioral_profile_uses_enjoyment(self):
        from OrbitServer.services.ai_suggestion_service import _build_behavioral_profile
        import datetime

        history = [
            {
                'action': 'joined',
                'attended': True,
                'enjoyment_rating': 5,
                'tags_snapshot': ['Hiking', 'Outdoors'],
                'created_at': datetime.datetime.utcnow().isoformat() + 'Z',
            },
        ]
        profile = _build_behavioral_profile(history)
        assert len(profile) == 1
        tags, weight = profile[0]
        assert 'Hiking' in tags
        # weight = action_score * decay_weight
        # action_score = (0.8 + 0.2) * 1.6 = 1.6
        # decay_weight ~ 1.0 (just created)
        assert weight > 1.5  # should be close to 1.6

    def test_behavioral_profile_low_enjoyment_reduces_weight(self):
        from OrbitServer.services.ai_suggestion_service import _build_behavioral_profile
        import datetime

        history = [
            {
                'action': 'joined',
                'attended': True,
                'enjoyment_rating': 1,
                'tags_snapshot': ['Gaming'],
                'created_at': datetime.datetime.utcnow().isoformat() + 'Z',
            },
        ]
        profile = _build_behavioral_profile(history)
        assert len(profile) == 1
        _, weight = profile[0]
        # action_score = (0.8 + 0.2) * 0.3 = 0.3
        assert weight < 0.35


class TestDisplayRescaling:
    """Verify the display rescaling from the earlier match score change."""

    def test_rescale_floor(self):
        from OrbitServer.services.ai_suggestion_service import _rescale_for_display, DISPLAY_FLOOR
        assert abs(_rescale_for_display(0.0) - DISPLAY_FLOOR) < 1e-9

    def test_rescale_ceiling(self):
        from OrbitServer.services.ai_suggestion_service import _rescale_for_display, DISPLAY_CEIL
        assert abs(_rescale_for_display(1.0) - DISPLAY_CEIL) < 1e-9

    def test_rescale_preserves_order(self):
        from OrbitServer.services.ai_suggestion_service import _rescale_for_display
        a = _rescale_for_display(0.3)
        b = _rescale_for_display(0.7)
        assert b > a

    def test_rescale_midpoint(self):
        from OrbitServer.services.ai_suggestion_service import (
            _rescale_for_display, DISPLAY_FLOOR, DISPLAY_CEIL,
        )
        mid = _rescale_for_display(0.5)
        expected = DISPLAY_FLOOR + 0.5 * (DISPLAY_CEIL - DISPLAY_FLOOR)
        assert abs(mid - expected) < 1e-9


class TestLightFMEnjoymentBonus:
    """Verify enjoyment weights are defined for LightFM training."""

    def test_enjoyment_weight_bonus_exists(self):
        from OrbitServer.services.lightfm_service import ENJOYMENT_WEIGHT_BONUS
        assert isinstance(ENJOYMENT_WEIGHT_BONUS, dict)
        assert 1 in ENJOYMENT_WEIGHT_BONUS
        assert 5 in ENJOYMENT_WEIGHT_BONUS

    def test_low_enjoyment_is_negative(self):
        from OrbitServer.services.lightfm_service import ENJOYMENT_WEIGHT_BONUS
        assert ENJOYMENT_WEIGHT_BONUS[1] < 0

    def test_high_enjoyment_is_positive(self):
        from OrbitServer.services.lightfm_service import ENJOYMENT_WEIGHT_BONUS
        assert ENJOYMENT_WEIGHT_BONUS[5] > 0

    def test_neutral_enjoyment_is_zero(self):
        from OrbitServer.services.lightfm_service import ENJOYMENT_WEIGHT_BONUS
        assert ENJOYMENT_WEIGHT_BONUS[3] == 0.0
