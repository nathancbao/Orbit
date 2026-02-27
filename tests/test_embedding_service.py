"""Tests for services/embedding_service.py"""

import numpy as np
import pytest
from unittest.mock import patch, MagicMock


class TestBuildEventText:
    def test_combines_title_desc_tags(self):
        from OrbitServer.services.embedding_service import _build_event_text
        event = {'title': 'Morning Run', 'description': 'Easy jog', 'tags': ['fitness', 'outdoors']}
        text = _build_event_text(event)
        assert 'Morning Run' in text
        assert 'Easy jog' in text
        assert 'fitness' in text
        assert 'outdoors' in text

    def test_handles_missing_tags(self):
        from OrbitServer.services.embedding_service import _build_event_text
        event = {'title': 'Study', 'description': 'Library session', 'tags': []}
        text = _build_event_text(event)
        assert 'Study' in text
        assert 'Library session' in text

    def test_handles_empty_description(self):
        from OrbitServer.services.embedding_service import _build_event_text
        event = {'title': 'Yoga', 'description': '', 'tags': ['wellness']}
        text = _build_event_text(event)
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


class TestGetOrCreateEventEmbedding:
    def test_returns_none_for_missing_event(self):
        from OrbitServer.services import embedding_service
        with patch.object(embedding_service, 'get_event', return_value=None):
            # Clear in-process cache
            embedding_service._embedding_cache.clear()
            result = embedding_service.get_or_create_event_embedding(999)
            assert result is None

    def test_uses_cached_embedding_from_datastore(self):
        from OrbitServer.services import embedding_service
        stored_vec = [0.1, 0.2, 0.3]
        event = {'id': 1, 'title': 'Test', 'embedding': stored_vec, 'tags': []}
        embedding_service._embedding_cache.clear()
        with patch.object(embedding_service, 'get_event', return_value=event):
            result = embedding_service.get_or_create_event_embedding(1)
            assert result is not None
            assert len(result) == 3

    def test_in_process_cache_hit_skips_datastore(self):
        from OrbitServer.services import embedding_service
        cached_vec = np.array([0.5, 0.6, 0.7], dtype=np.float32)
        embedding_service._embedding_cache[42] = cached_vec
        with patch.object(embedding_service, 'get_event') as mock_get:
            result = embedding_service.get_or_create_event_embedding(42)
            mock_get.assert_not_called()
            assert result is not None
        # Cleanup
        embedding_service._embedding_cache.pop(42, None)

    def test_returns_none_on_api_failure(self):
        from OrbitServer.services import embedding_service
        event = {'id': 5, 'title': 'Hike', 'description': 'Trail', 'tags': ['outdoors'], 'embedding': None}
        embedding_service._embedding_cache.clear()
        with patch.object(embedding_service, 'get_event', return_value=event):
            with patch.object(embedding_service, '_call_anthropic_embedding', return_value=None):
                result = embedding_service.get_or_create_event_embedding(5)
                assert result is None

    def test_generates_and_stores_embedding_on_cache_miss(self):
        from OrbitServer.services import embedding_service
        event = {'id': 7, 'title': 'Swim', 'description': 'Pool', 'tags': ['fitness'], 'embedding': None}
        fake_embedding = [0.1] * 512
        embedding_service._embedding_cache.clear()
        with patch.object(embedding_service, 'get_event', return_value=event):
            with patch.object(embedding_service, '_call_anthropic_embedding', return_value=fake_embedding):
                with patch.object(embedding_service, 'store_event_embedding') as mock_store:
                    result = embedding_service.get_or_create_event_embedding(7)
                    assert result is not None
                    assert len(result) == 512
                    mock_store.assert_called_once_with(7, fake_embedding)
        embedding_service._embedding_cache.pop(7, None)


class TestInvalidateCache:
    def test_removes_event_from_cache(self):
        from OrbitServer.services import embedding_service
        embedding_service._embedding_cache[99] = np.array([1.0, 2.0])
        embedding_service.invalidate_cache(99)
        assert 99 not in embedding_service._embedding_cache

    def test_safe_to_invalidate_nonexistent(self):
        from OrbitServer.services import embedding_service
        # Should not raise
        embedding_service.invalidate_cache(99999)
