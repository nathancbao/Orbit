"""Tests for services/lightfm_service.py"""

import numpy as np
import pytest
from unittest.mock import patch, MagicMock


def _make_dataset(user_ids=(1,), item_ids=(10, 20)):
    """Build a minimal real LightFM Dataset for use in tests."""
    from lightfm.data import Dataset
    ds = Dataset()
    ds.fit(users=user_ids, items=item_ids)
    return ds


class TestSigmoid:
    def test_zero_maps_to_half(self):
        from OrbitServer.services.lightfm_service import _sigmoid
        assert abs(_sigmoid(0.0) - 0.5) < 1e-6

    def test_large_positive_maps_near_one(self):
        from OrbitServer.services.lightfm_service import _sigmoid
        assert _sigmoid(10.0) > 0.99

    def test_large_negative_maps_near_zero(self):
        from OrbitServer.services.lightfm_service import _sigmoid
        assert _sigmoid(-10.0) < 0.01


class TestGetLightFMScores:
    def test_returns_zeros_when_model_not_trained(self):
        from OrbitServer.services.lightfm_service import get_lightfm_scores
        with patch('OrbitServer.services.lightfm_service._get_model', return_value=(None, None)):
            result = get_lightfm_scores(1, [10, 20])
            assert result == {10: 0.0, 20: 0.0}

    def test_returns_empty_for_empty_event_list(self):
        from OrbitServer.services.lightfm_service import get_lightfm_scores
        result = get_lightfm_scores(1, [])
        assert result == {}

    def test_returns_zeros_for_unknown_user(self):
        from OrbitServer.services.lightfm_service import get_lightfm_scores
        ds = _make_dataset(user_ids=[99], item_ids=[10, 20])
        mock_model = MagicMock()
        with patch('OrbitServer.services.lightfm_service._get_model', return_value=(mock_model, ds)):
            # user_id=1 is not in dataset (only 99 is)
            result = get_lightfm_scores(1, [10, 20])
            assert result == {10: 0.0, 20: 0.0}
            mock_model.predict.assert_not_called()

    def test_applies_sigmoid_to_raw_scores(self):
        from OrbitServer.services.lightfm_service import get_lightfm_scores, _sigmoid
        ds = _make_dataset(user_ids=[1], item_ids=[10, 20])
        mock_model = MagicMock()
        mock_model.predict.return_value = np.array([2.0, -1.0])
        with patch('OrbitServer.services.lightfm_service._get_model', return_value=(mock_model, ds)):
            result = get_lightfm_scores(1, [10, 20])
            assert abs(result[10] - _sigmoid(2.0)) < 1e-6
            assert abs(result[20] - _sigmoid(-1.0)) < 1e-6

    def test_unknown_events_get_zero(self):
        from OrbitServer.services.lightfm_service import get_lightfm_scores
        ds = _make_dataset(user_ids=[1], item_ids=[10])
        mock_model = MagicMock()
        mock_model.predict.return_value = np.array([1.5])
        with patch('OrbitServer.services.lightfm_service._get_model', return_value=(mock_model, ds)):
            # event 99 is not in dataset
            result = get_lightfm_scores(1, [10, 99])
            assert result[99] == 0.0
            assert result[10] > 0.0

    def test_handles_prediction_exception_gracefully(self):
        from OrbitServer.services.lightfm_service import get_lightfm_scores
        ds = _make_dataset(user_ids=[1], item_ids=[10, 20])
        mock_model = MagicMock()
        mock_model.predict.side_effect = RuntimeError("predict failed")
        with patch('OrbitServer.services.lightfm_service._get_model', return_value=(mock_model, ds)):
            result = get_lightfm_scores(1, [10, 20])
            assert result == {10: 0.0, 20: 0.0}


class TestRetrain:
    def test_retrain_calls_train(self):
        from OrbitServer.services import lightfm_service
        with patch.object(lightfm_service, '_train') as mock_train:
            lightfm_service.retrain()
            mock_train.assert_called_once()

    def test_retrain_resets_trained_flag_before_training(self):
        from OrbitServer.services import lightfm_service
        lightfm_service._trained = True
        seen_states = []

        def capture_state():
            seen_states.append(lightfm_service._trained)

        with patch.object(lightfm_service, '_train', side_effect=capture_state):
            lightfm_service.retrain()
            # _trained should have been False when _train was called
            assert seen_states[0] is False
