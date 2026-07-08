"""Tests for the analytics event pipeline (Batch G).

Covers the pseudonymize util, analytics_service.emit / ingest_batch, the
POST /api/analytics/events endpoint, the model idempotency contract, and the
account-deletion purge.
"""

import json
from unittest.mock import patch

from OrbitServer.utils.auth import create_access_token
from OrbitServer.utils.analytics_id import pseudonymize
from OrbitServer.services import analytics_service


def _auth_headers(user_id=1):
    return {"Authorization": f"Bearer {create_access_token(user_id)}"}


class TestPseudonymize:
    def test_deterministic(self):
        assert pseudonymize(42) == pseudonymize(42)
        # accepts str or int, same underlying id -> same token
        assert pseudonymize(42) == pseudonymize("42")

    def test_distinct_ids_differ(self):
        assert pseudonymize(42) != pseudonymize(43)

    def test_is_sha256_hex(self):
        token = pseudonymize(42)
        assert len(token) == 64
        int(token, 16)  # valid hex


class TestEmit:
    def test_builds_full_envelope(self):
        with patch.object(analytics_service, 'create_analytics_event') as m:
            analytics_service.emit('mission_joined', 7, {'mission_id': 'm1'})
        assert m.call_count == 1
        env = m.call_args[0][0]
        assert env['event_name'] == 'mission_joined'
        assert env['user_pseudo_id'] == pseudonymize(7)
        assert env['properties'] == {'mission_id': 'm1'}
        assert env['received_ts'] and env['event_id']
        # raw user id is never in the stored envelope
        assert 'user_id' not in env

    def test_unknown_event_dropped(self):
        with patch.object(analytics_service, 'create_analytics_event') as m:
            result = analytics_service.emit('totally_made_up', 7)
        assert result is None
        m.assert_not_called()

    def test_best_effort_swallows_write_failure(self):
        with patch.object(analytics_service, 'create_analytics_event',
                          side_effect=RuntimeError("datastore down")):
            # Must not raise — analytics can never break a core flow.
            result = analytics_service.emit('mission_joined', 7)
        assert result is None

    def test_respects_supplied_event_id(self):
        with patch.object(analytics_service, 'create_analytics_event') as m:
            analytics_service.emit('app_opened', 7, event_id='fixed-123')
        assert m.call_args[0][0]['event_id'] == 'fixed-123'


class TestIngestBatch:
    def test_accepts_valid_rejects_invalid(self):
        events = [
            {'event_name': 'app_opened'},
            {'event_name': 'mission_viewed', 'properties': {'mission_id': 'm1'}},
            {'event_name': 'not_a_real_event'},
            'garbage',
        ]
        with patch.object(analytics_service, 'create_analytics_event'):
            accepted, rejected = analytics_service.ingest_batch(9, events)
        assert accepted == 2
        assert rejected == 2

    def test_non_list_input(self):
        accepted, rejected = analytics_service.ingest_batch(9, {'not': 'a list'})
        assert (accepted, rejected) == (0, 0)

    def test_caps_batch_size(self):
        events = [{'event_name': 'app_opened'}] * (analytics_service.MAX_BATCH_SIZE + 25)
        with patch.object(analytics_service, 'create_analytics_event') as m:
            accepted, _ = analytics_service.ingest_batch(9, events)
        assert accepted == analytics_service.MAX_BATCH_SIZE
        assert m.call_count == analytics_service.MAX_BATCH_SIZE

    def test_pseudonymizes_under_authenticated_user(self):
        # Even if a client tries to smuggle another identity, ingest uses the
        # authenticated user id passed by the endpoint.
        events = [{'event_name': 'app_opened', 'user_pseudo_id': 'attacker'}]
        with patch.object(analytics_service, 'create_analytics_event') as m:
            analytics_service.ingest_batch(9, events)
        assert m.call_args[0][0]['user_pseudo_id'] == pseudonymize(9)


class TestIngestEndpoint:
    def test_requires_auth(self, client):
        resp = client.post('/api/analytics/events', json={'events': []})
        assert resp.status_code == 401

    def test_accepts_batch(self, client):
        with patch.object(analytics_service, 'create_analytics_event'):
            resp = client.post('/api/analytics/events',
                               headers=_auth_headers(),
                               json={'events': [{'event_name': 'app_opened'},
                                                {'event_name': 'bogus'}]})
        assert resp.status_code == 200
        body = json.loads(resp.data)['data']
        assert body['accepted'] == 1
        assert body['rejected'] == 1

    def test_rejects_non_array_body(self, client):
        resp = client.post('/api/analytics/events',
                           headers=_auth_headers(), json={'events': 'nope'})
        assert resp.status_code == 400

    def test_rejects_oversized_batch(self, client):
        events = [{'event_name': 'app_opened'}] * (analytics_service.MAX_BATCH_SIZE + 1)
        resp = client.post('/api/analytics/events',
                           headers=_auth_headers(), json={'events': events})
        assert resp.status_code == 400


class TestModelIdempotencyContract:
    def test_event_id_is_the_key(self):
        # The AnalyticsEvent kind is keyed by event_id so a retried event
        # overwrites rather than double-counting.
        from OrbitServer.models import models
        with patch.object(models, 'client') as mock_client:
            models.create_analytics_event({'event_id': 'abc123', 'event_name': 'app_opened'})
        mock_client.key.assert_called_once_with('AnalyticsEvent', 'abc123')


class TestDeletionCascade:
    def test_purges_analytics_for_user_pseudo(self):
        from OrbitServer.services import user_service
        with patch('OrbitServer.services.user_service.get_user', return_value={'id': 5}), \
             patch('OrbitServer.services.user_service.delete_user'), \
             patch('OrbitServer.models.models.get_user_pods', return_value=[]), \
             patch('OrbitServer.models.models.list_friendships', return_value=[]), \
             patch('OrbitServer.models.models.list_incoming_friend_requests', return_value=[]), \
             patch('OrbitServer.models.models.list_outgoing_friend_requests', return_value=[]), \
             patch('OrbitServer.models.models.list_signals_for_user', return_value=[]), \
             patch('OrbitServer.models.models.delete_analytics_events_for_pseudo') as purge:
            user_service.delete_user_account(5)
        purge.assert_called_once_with(pseudonymize(5))
