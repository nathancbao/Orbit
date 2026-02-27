"""Tests for services/ai_suggestion_service.py — hybrid ML scorer."""

import datetime
import math
from unittest.mock import patch, MagicMock

import numpy as np
import pytest


class TestJaccard:
    def test_empty_sets_return_zero(self):
        from OrbitServer.services.ai_suggestion_service import _jaccard
        assert _jaccard(set(), set()) == 0.0

    def test_identical_sets_return_one(self):
        from OrbitServer.services.ai_suggestion_service import _jaccard
        s = {'a', 'b', 'c'}
        assert _jaccard(s, s) == 1.0

    def test_disjoint_sets_return_zero(self):
        from OrbitServer.services.ai_suggestion_service import _jaccard
        assert _jaccard({'a', 'b'}, {'c', 'd'}) == 0.0

    def test_partial_overlap(self):
        from OrbitServer.services.ai_suggestion_service import _jaccard
        score = _jaccard({'a', 'b', 'c'}, {'b', 'c', 'd'})
        # intersection=2, union=4 → 0.5
        assert abs(score - 0.5) < 1e-6


class TestDecayWeight:
    def test_very_recent_returns_near_one(self):
        from OrbitServer.services.ai_suggestion_service import _decay_weight
        now = datetime.datetime.utcnow()
        w = _decay_weight(now)
        assert w > 0.99

    def test_14_day_old_returns_near_half(self):
        from OrbitServer.services.ai_suggestion_service import _decay_weight
        past = datetime.datetime.utcnow() - datetime.timedelta(days=14)
        w = _decay_weight(past)
        expected = math.exp(-0.05 * 14)  # ≈ 0.496
        assert abs(w - expected) < 0.01

    def test_none_created_at_returns_zero(self):
        from OrbitServer.services.ai_suggestion_service import _decay_weight
        assert _decay_weight(None) == 0.0


class TestActionScore:
    def test_joined_with_attendance_returns_one(self):
        from OrbitServer.services.ai_suggestion_service import _action_score
        assert _action_score('joined', True) == 1.0

    def test_joined_no_attendance_data(self):
        from OrbitServer.services.ai_suggestion_service import _action_score
        assert _action_score('joined', None) == 0.8

    def test_skipped_returns_negative(self):
        from OrbitServer.services.ai_suggestion_service import _action_score
        assert _action_score('skipped', None) < 0

    def test_browsed_returns_small_positive(self):
        from OrbitServer.services.ai_suggestion_service import _action_score
        score = _action_score('browsed', None)
        assert 0 < score < 0.5


class TestBuildBehavioralProfile:
    def test_empty_history_returns_empty(self):
        from OrbitServer.services.ai_suggestion_service import _build_behavioral_profile
        assert _build_behavioral_profile([]) == []

    def test_skipped_actions_excluded(self):
        from OrbitServer.services.ai_suggestion_service import _build_behavioral_profile
        history = [{'action': 'skipped', 'tags_snapshot': ['a'], 'attended': None,
                    'created_at': datetime.datetime.utcnow()}]
        assert _build_behavioral_profile(history) == []

    def test_legacy_records_without_tags_excluded(self):
        from OrbitServer.services.ai_suggestion_service import _build_behavioral_profile
        history = [{'action': 'joined', 'tags_snapshot': [], 'attended': None,
                    'created_at': datetime.datetime.utcnow()}]
        assert _build_behavioral_profile(history) == []

    def test_recent_joined_event_has_high_weight(self):
        from OrbitServer.services.ai_suggestion_service import _build_behavioral_profile
        history = [{'action': 'joined', 'tags_snapshot': ['hiking'], 'attended': None,
                    'created_at': datetime.datetime.utcnow()}]
        profile = _build_behavioral_profile(history)
        assert len(profile) == 1
        tags, weight = profile[0]
        assert 'hiking' in tags
        assert weight > 0.7  # near 0.8 (joined score) * 1.0 (recent weight)


class TestComputeBehavioralScore:
    def test_no_profile_returns_zero(self):
        from OrbitServer.services.ai_suggestion_service import _compute_behavioral_score
        assert _compute_behavioral_score({'hiking'}, []) == 0.0

    def test_no_event_tags_returns_zero(self):
        from OrbitServer.services.ai_suggestion_service import _compute_behavioral_score
        profile = [({'hiking'}, 0.8)]
        assert _compute_behavioral_score(set(), profile) == 0.0

    def test_high_overlap_returns_high_score(self):
        from OrbitServer.services.ai_suggestion_service import _compute_behavioral_score
        profile = [({'hiking', 'outdoors'}, 1.0)]
        score = _compute_behavioral_score({'hiking', 'outdoors'}, profile)
        assert score == 1.0

    def test_no_overlap_returns_zero(self):
        from OrbitServer.services.ai_suggestion_service import _compute_behavioral_score
        profile = [({'coffee', 'study'}, 0.8)]
        assert _compute_behavioral_score({'hiking', 'fitness'}, profile) == 0.0

    def test_result_clamped_to_one(self):
        from OrbitServer.services.ai_suggestion_service import _compute_behavioral_score
        # Even very high weights should not exceed 1.0
        profile = [({'a', 'b'}, 100.0)]
        score = _compute_behavioral_score({'a', 'b'}, profile)
        assert score <= 1.0


class TestNormalizeTrust:
    def test_zero_trust_returns_zero(self):
        from OrbitServer.services.ai_suggestion_service import _normalize_trust
        assert _normalize_trust(0.0) == 0.0

    def test_max_trust_returns_one(self):
        from OrbitServer.services.ai_suggestion_service import _normalize_trust
        assert _normalize_trust(5.0) == 1.0

    def test_midpoint_trust_returns_point_six(self):
        from OrbitServer.services.ai_suggestion_service import _normalize_trust
        assert abs(_normalize_trust(3.0) - 0.6) < 1e-6

    def test_invalid_trust_returns_default(self):
        from OrbitServer.services.ai_suggestion_service import _normalize_trust
        assert _normalize_trust(None) == 0.6


class TestGetSuggestedEvents:
    def _make_event(self, eid, tags):
        return {'id': eid, 'title': f'Event {eid}', 'description': '', 'tags': tags, 'status': 'open'}

    @patch('OrbitServer.services.ai_suggestion_service.get_user_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.get_or_create_event_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.list_events')
    @patch('OrbitServer.services.ai_suggestion_service.get_user_event_history')
    @patch('OrbitServer.services.ai_suggestion_service.get_profile')
    def test_returns_events_without_embedding(self, mock_profile, mock_history,
                                               mock_list, mock_embed, mock_user_embed):
        mock_profile.return_value = {'interests': ['hiking'], 'trust_score': 3.0}
        mock_history.return_value = []
        mock_list.return_value = [self._make_event(1, ['hiking'])]

        from OrbitServer.services.ai_suggestion_service import get_suggested_events
        result = get_suggested_events(user_id=1)
        assert len(result) == 1

    @patch('OrbitServer.services.ai_suggestion_service.get_user_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.get_or_create_event_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.list_events')
    @patch('OrbitServer.services.ai_suggestion_service.get_user_event_history')
    @patch('OrbitServer.services.ai_suggestion_service.get_profile')
    def test_excludes_joined_events(self, mock_profile, mock_history,
                                    mock_list, mock_embed, mock_user_embed):
        mock_profile.return_value = {'interests': ['hiking'], 'trust_score': 3.0}
        mock_history.return_value = [{'event_id': 1, 'action': 'joined', 'tags_snapshot': [], 'attended': None, 'created_at': None}]
        mock_list.return_value = [self._make_event(1, ['hiking']), self._make_event(2, ['outdoors'])]

        from OrbitServer.services.ai_suggestion_service import get_suggested_events
        result = get_suggested_events(user_id=1)
        ids = [e['id'] for e in result]
        assert 1 not in ids
        assert 2 in ids

    @patch('OrbitServer.services.ai_suggestion_service.get_user_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.get_or_create_event_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.list_events')
    @patch('OrbitServer.services.ai_suggestion_service.get_user_event_history')
    @patch('OrbitServer.services.ai_suggestion_service.get_profile')
    def test_excludes_skipped_events(self, mock_profile, mock_history,
                                     mock_list, mock_embed, mock_user_embed):
        mock_profile.return_value = {'interests': ['hiking'], 'trust_score': 3.0}
        mock_history.return_value = [{'event_id': 3, 'action': 'skipped', 'tags_snapshot': [], 'attended': None, 'created_at': None}]
        mock_list.return_value = [self._make_event(3, ['hiking']), self._make_event(4, ['coffee'])]

        from OrbitServer.services.ai_suggestion_service import get_suggested_events
        result = get_suggested_events(user_id=1)
        ids = [e['id'] for e in result]
        assert 3 not in ids
        assert 4 in ids

    @patch('OrbitServer.services.ai_suggestion_service.get_user_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.get_or_create_event_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.list_events')
    @patch('OrbitServer.services.ai_suggestion_service.get_user_event_history')
    @patch('OrbitServer.services.ai_suggestion_service.get_profile')
    def test_respects_limit(self, mock_profile, mock_history,
                            mock_list, mock_embed, mock_user_embed):
        mock_profile.return_value = {'interests': ['hiking'], 'trust_score': 3.0}
        mock_history.return_value = []
        mock_list.return_value = [self._make_event(i, ['hiking']) for i in range(10)]

        from OrbitServer.services.ai_suggestion_service import get_suggested_events
        result = get_suggested_events(user_id=1, limit=3)
        assert len(result) <= 3

    @patch('OrbitServer.services.ai_suggestion_service.get_user_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.get_or_create_event_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.list_events')
    @patch('OrbitServer.services.ai_suggestion_service.get_user_event_history')
    @patch('OrbitServer.services.ai_suggestion_service.get_profile')
    def test_events_sorted_descending(self, mock_profile, mock_history,
                                      mock_list, mock_embed, mock_user_embed):
        mock_profile.return_value = {'interests': ['hiking'], 'trust_score': 3.0}
        mock_history.return_value = []
        mock_list.return_value = [
            self._make_event(1, ['coffee']),   # no overlap
            self._make_event(2, ['hiking']),   # full overlap
        ]

        from OrbitServer.services.ai_suggestion_service import get_suggested_events
        result = get_suggested_events(user_id=1, limit=5)
        scores = [e['match_score'] for e in result]
        assert scores == sorted(scores, reverse=True)

    @patch('OrbitServer.services.ai_suggestion_service.get_user_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.get_or_create_event_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.list_events')
    @patch('OrbitServer.services.ai_suggestion_service.get_user_event_history')
    @patch('OrbitServer.services.ai_suggestion_service.get_profile')
    def test_match_score_in_zero_one_range(self, mock_profile, mock_history,
                                           mock_list, mock_embed, mock_user_embed):
        mock_profile.return_value = {'interests': ['hiking'], 'trust_score': 5.0}
        mock_history.return_value = []
        mock_list.return_value = [self._make_event(1, ['hiking'])]

        from OrbitServer.services.ai_suggestion_service import get_suggested_events
        result = get_suggested_events(user_id=1)
        for event in result:
            assert 0.0 <= event['match_score'] <= 1.0

    @patch('OrbitServer.services.ai_suggestion_service.get_user_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.get_or_create_event_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.list_events')
    @patch('OrbitServer.services.ai_suggestion_service.get_user_event_history')
    @patch('OrbitServer.services.ai_suggestion_service.get_profile')
    def test_suggestion_reason_is_string(self, mock_profile, mock_history,
                                         mock_list, mock_embed, mock_user_embed):
        mock_profile.return_value = {'interests': ['hiking'], 'trust_score': 3.0}
        mock_history.return_value = []
        mock_list.return_value = [self._make_event(1, ['hiking'])]

        from OrbitServer.services.ai_suggestion_service import get_suggested_events
        result = get_suggested_events(user_id=1)
        assert isinstance(result[0]['suggestion_reason'], str)
        assert len(result[0]['suggestion_reason']) > 0

    @patch('OrbitServer.services.ai_suggestion_service.get_user_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.get_or_create_event_embedding', return_value=None)
    @patch('OrbitServer.services.ai_suggestion_service.list_events')
    @patch('OrbitServer.services.ai_suggestion_service.get_user_event_history')
    @patch('OrbitServer.services.ai_suggestion_service.get_profile')
    def test_empty_candidates_returns_empty(self, mock_profile, mock_history,
                                            mock_list, mock_embed, mock_user_embed):
        mock_profile.return_value = {'interests': ['hiking'], 'trust_score': 3.0}
        mock_history.return_value = []
        mock_list.return_value = []

        from OrbitServer.services.ai_suggestion_service import get_suggested_events
        assert get_suggested_events(user_id=1) == []
