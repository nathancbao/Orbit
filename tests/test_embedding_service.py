"""Tests for services/embedding_service.py"""

import numpy as np
import pytest
from unittest.mock import patch, MagicMock


class TestBuildMissionText:
    def test_combines_title_desc_tags(self):
        from OrbitServer.services.embedding_service import _build_mission_text
        mission = {'title': 'Morning Run', 'description': 'Easy jog', 'tags': ['fitness', 'outdoors']}
        text = _build_mission_text(mission)
        assert 'Morning Run' in text
        assert 'Easy jog' in text
        assert 'fitness' in text
        assert 'outdoors' in text

    def test_handles_missing_tags(self):
        from OrbitServer.services.embedding_service import _build_mission_text
        mission = {'title': 'Study', 'description': 'Library session', 'tags': []}
        text = _build_mission_text(mission)
        assert 'Study' in text
        assert 'Library session' in text

    def test_handles_empty_description(self):
        from OrbitServer.services.embedding_service import _build_mission_text
        mission = {'title': 'Yoga', 'description': '', 'tags': ['wellness']}
        text = _build_mission_text(mission)
        assert 'Yoga' in text
        assert 'wellness' in text


class TestCosineSimilarity:
    def test_identical_vectors_return_one(self):
        from OrbitServer.services.embedding_service import cosine_similarity
        v = np.array([1.0, 2.0, 3.0])
        assert abs(cosine_similarity(v, v) - 1.0) < 1e-6

    def test_orthogonal_vectors_return_zero(self):
        from OrbitServer.services.embedding_service import cosine_similarity
        a = np.array([1.0, 0.0, 0.0])
        b = np.array([0.0, 1.0, 0.0])
        assert abs(cosine_similarity(a, b)) < 1e-6

    def test_zero_vector_returns_zero(self):
        from OrbitServer.services.embedding_service import cosine_similarity
        a = np.array([0.0, 0.0, 0.0])
        b = np.array([1.0, 2.0, 3.0])
        assert cosine_similarity(a, b) == 0.0

    def test_partial_similarity(self):
        from OrbitServer.services.embedding_service import cosine_similarity
        a = np.array([1.0, 1.0, 0.0])
        b = np.array([1.0, 0.0, 0.0])
        sim = cosine_similarity(a, b)
        assert 0.0 < sim < 1.0


class TestGetOrCreateMissionEmbedding:
    def test_returns_none_for_missing_mission(self):
        from OrbitServer.services import embedding_service
        with patch.object(embedding_service, 'get_mission', return_value=None):
            # Clear in-process cache
            embedding_service._embedding_cache.clear()
            result = embedding_service.get_or_create_mission_embedding(999)
            assert result is None

    def test_uses_cached_embedding_from_datastore(self):
        from OrbitServer.services import embedding_service
        stored_vec = [0.1, 0.2, 0.3]
        mission = {'id': 1, 'title': 'Test', 'embedding': stored_vec, 'tags': []}
        embedding_service._embedding_cache.clear()
        with patch.object(embedding_service, 'get_mission', return_value=mission):
            result = embedding_service.get_or_create_mission_embedding(1)
            assert result is not None
            assert len(result) == 3

    def test_in_process_cache_hit_skips_datastore(self):
        from OrbitServer.services import embedding_service
        cached_vec = np.array([0.5, 0.6, 0.7], dtype=np.float32)
        embedding_service._embedding_cache[42] = cached_vec
        with patch.object(embedding_service, 'get_mission') as mock_get:
            result = embedding_service.get_or_create_mission_embedding(42)
            mock_get.assert_not_called()
            assert result is not None
        # Cleanup
        embedding_service._embedding_cache.pop(42, None)

    def test_returns_none_when_generation_fails(self):
        from OrbitServer.services import embedding_service
        mission = {'id': 5, 'title': 'Hike', 'description': 'Trail', 'tags': ['outdoors'], 'embedding': None}
        embedding_service._embedding_cache.clear()
        with patch.object(embedding_service, 'get_mission', return_value=mission):
            with patch.object(embedding_service, '_generate_embedding', return_value=None):
                result = embedding_service.get_or_create_mission_embedding(5)
                assert result is None

    def test_generates_and_stores_when_missing(self):
        from OrbitServer.services import embedding_service
        mission = {'id': 7, 'title': 'Board Games', 'description': 'Fun', 'tags': ['games'], 'embedding': None}
        fake_vec = np.array([0.1, 0.2, 0.3], dtype=np.float32)
        embedding_service._embedding_cache.clear()
        with patch.object(embedding_service, 'get_mission', return_value=mission):
            with patch.object(embedding_service, '_generate_embedding', return_value=fake_vec):
                with patch.object(embedding_service, 'store_mission_embedding') as mock_store:
                    result = embedding_service.get_or_create_mission_embedding(7)
                    assert result is not None
                    assert np.allclose(result, fake_vec)
                    mock_store.assert_called_once_with(7, fake_vec.tolist())
        embedding_service._embedding_cache.pop(7, None)


class TestGenerateEmbedding:
    def test_returns_float32_array(self):
        from OrbitServer.services import embedding_service
        fake_vec = np.array([0.1, 0.2, 0.3], dtype=np.float64)
        mock_model = MagicMock()
        mock_model.embed.return_value = iter([fake_vec])
        with patch.object(embedding_service, '_get_model', return_value=mock_model):
            result = embedding_service._generate_embedding("some text")
            assert isinstance(result, np.ndarray)
            assert result.dtype == np.float32

    def test_returns_none_on_model_failure(self):
        from OrbitServer.services import embedding_service
        with patch.object(embedding_service, '_get_model', side_effect=RuntimeError("load failed")):
            result = embedding_service._generate_embedding("some text")
            assert result is None

    def test_get_user_embedding_returns_array(self):
        from OrbitServer.services import embedding_service
        fake_vec = np.array([0.5, 0.6], dtype=np.float32)
        with patch.object(embedding_service, '_generate_embedding', return_value=fake_vec) as mock_gen:
            result = embedding_service.get_user_embedding(['hiking', 'photography'])
            assert result is not None
            mock_gen.assert_called_once()
            assert 'hiking' in mock_gen.call_args[0][0]

    def test_get_user_embedding_empty_interests(self):
        from OrbitServer.services import embedding_service
        fake_vec = np.array([0.1], dtype=np.float32)
        with patch.object(embedding_service, '_generate_embedding', return_value=fake_vec) as mock_gen:
            result = embedding_service.get_user_embedding([])
            mock_gen.assert_called_once()
            assert result is not None


class TestInvalidateCache:
    def test_removes_mission_from_cache(self):
        from OrbitServer.services import embedding_service
        embedding_service._embedding_cache[99] = np.array([1.0, 2.0])
        embedding_service.invalidate_cache(99)
        assert 99 not in embedding_service._embedding_cache

    def test_safe_to_invalidate_nonexistent(self):
        from OrbitServer.services import embedding_service
        # Should not raise
        embedding_service.invalidate_cache(99999)
