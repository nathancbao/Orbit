"""Tests for api/signals.py endpoints."""

import json
from unittest.mock import patch
from OrbitServer.utils.auth import create_access_token


def auth_header(user_id=1):
    token = create_access_token(user_id)
    return {"Authorization": f"Bearer {token}"}


VALID_SIGNAL = {
    "title": "Sports",
    "activity_category": "Sports",
    "custom_activity_name": None,
    "min_group_size": 3,
    "max_group_size": 6,
    "availability": [
        {"date": "2026-03-01", "time_blocks": ["morning", "afternoon"]}
    ],
    "description": "pickup basketball",
}


# ── GET /api/signals ─────────────────────────────────────────────────────────

class TestListSignals:
    def test_rejects_unauthenticated(self, client):
        resp = client.get('/api/signals')
        assert resp.status_code == 401

    @patch('OrbitServer.api.signals.get_user_signals')
    def test_returns_user_signals(self, mock_get, client):
        mock_get.return_value = ([
            {"id": "uuid-1", "title": "Sports", "status": "pending"},
        ], None)
        resp = client.get('/api/signals', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
        assert len(body["data"]) == 1

    @patch('OrbitServer.api.signals.get_user_signals')
    def test_returns_only_own_signals(self, mock_get, client):
        """Service layer receives g.user_id — verify it's called with the right user."""
        mock_get.return_value = ([], None)
        client.get('/api/signals', headers=auth_header(user_id=42))
        mock_get.assert_called_once_with(42)


# ── POST /api/signals ────────────────────────────────────────────────────────

class TestCreateSignal:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/signals', json=VALID_SIGNAL)
        assert resp.status_code == 401

    @patch('OrbitServer.api.signals.create_new_signal')
    def test_creates_valid_signal(self, mock_create, client):
        mock_create.return_value = ({"id": "uuid-1", **VALID_SIGNAL, "status": "pending"}, None)
        resp = client.post('/api/signals', headers=auth_header(), json=VALID_SIGNAL)
        body = json.loads(resp.data)
        assert resp.status_code == 201
        assert body["success"] is True

    def test_rejects_missing_category(self, client):
        bad = {**VALID_SIGNAL}
        del bad["activity_category"]
        resp = client.post('/api/signals', headers=auth_header(), json=bad)
        assert resp.status_code == 400

    def test_rejects_invalid_category(self, client):
        bad = {**VALID_SIGNAL, "activity_category": "NotACategory"}
        resp = client.post('/api/signals', headers=auth_header(), json=bad)
        assert resp.status_code == 400

    def test_rejects_empty_availability(self, client):
        bad = {**VALID_SIGNAL, "availability": []}
        resp = client.post('/api/signals', headers=auth_header(), json=bad)
        assert resp.status_code == 400

    def test_rejects_min_greater_than_max(self, client):
        bad = {**VALID_SIGNAL, "min_group_size": 8, "max_group_size": 3}
        resp = client.post('/api/signals', headers=auth_header(), json=bad)
        assert resp.status_code == 400

    def test_rejects_invalid_time_block(self, client):
        bad = {**VALID_SIGNAL, "availability": [
            {"date": "2026-03-01", "time_blocks": ["midnight"]}
        ]}
        resp = client.post('/api/signals', headers=auth_header(), json=bad)
        assert resp.status_code == 400

    def test_custom_category_requires_name(self, client):
        bad = {**VALID_SIGNAL, "activity_category": "Custom", "custom_activity_name": None}
        resp = client.post('/api/signals', headers=auth_header(), json=bad)
        assert resp.status_code == 400


# ── DELETE /api/signals/<id> ─────────────────────────────────────────────────

class TestDeleteSignal:
    def test_rejects_unauthenticated(self, client):
        resp = client.delete('/api/signals/uuid-1')
        assert resp.status_code == 401

    @patch('OrbitServer.api.signals.remove_signal')
    def test_deletes_own_signal(self, mock_remove, client):
        mock_remove.return_value = (True, None, None)
        resp = client.delete('/api/signals/uuid-1', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True

    @patch('OrbitServer.api.signals.remove_signal')
    def test_rejects_non_creator(self, mock_remove, client):
        mock_remove.return_value = (False, "Only the creator can delete this signal", 403)
        resp = client.delete('/api/signals/uuid-1', headers=auth_header())
        assert resp.status_code == 403

    @patch('OrbitServer.api.signals.remove_signal')
    def test_404_for_unknown_signal(self, mock_remove, client):
        mock_remove.return_value = (False, "Signal not found", 404)
        resp = client.delete('/api/signals/nonexistent', headers=auth_header())
        assert resp.status_code == 404


# ── GET /api/signals/discover ────────────────────────────────────────────────

class TestDiscoverSignals:
    def test_rejects_unauthenticated(self, client):
        resp = client.get('/api/signals/discover')
        assert resp.status_code == 401

    @patch('OrbitServer.api.signals.get_all_signals')
    def test_returns_signals(self, mock_discover, client):
        mock_discover.return_value = ([
            {"id": "uuid-1", "title": "Sports", "status": "pending"},
            {"id": "uuid-2", "title": "Food", "status": "pending"},
        ], None, None)
        resp = client.get('/api/signals/discover', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
        assert len(body["data"]["signals"]) == 2
        assert body["data"]["next_cursor"] is None

    @patch('OrbitServer.api.signals.get_all_signals')
    def test_returns_empty_list(self, mock_discover, client):
        mock_discover.return_value = ([], None, None)
        resp = client.get('/api/signals/discover', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["data"]["signals"] == []


# ── POST /api/signals/<id>/rsvp ─────────────────────────────────────────────

class TestRsvpSignal:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/signals/uuid-1/rsvp')
        assert resp.status_code == 401

    @patch('OrbitServer.api.signals.rsvp_signal')
    def test_rsvp_success(self, mock_rsvp, client):
        mock_rsvp.return_value = (
            {"id": "uuid-1", "rsvps": [1], "status": "pending", "min_group_size": 2},
            None,
        )
        resp = client.post('/api/signals/uuid-1/rsvp', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True

    @patch('OrbitServer.api.signals.rsvp_signal')
    def test_rsvp_duplicate_rejected(self, mock_rsvp, client):
        mock_rsvp.return_value = (None, "You have already RSVP'd to this signal")
        resp = client.post('/api/signals/uuid-1/rsvp', headers=auth_header())
        assert resp.status_code == 409

    @patch('OrbitServer.api.signals.rsvp_signal')
    def test_rsvp_not_found(self, mock_rsvp, client):
        mock_rsvp.return_value = (None, "Signal not found")
        resp = client.post('/api/signals/nonexistent/rsvp', headers=auth_header())
        assert resp.status_code == 404

    @patch('OrbitServer.api.signals.rsvp_signal')
    def test_rsvp_activates_at_min_group_size(self, mock_rsvp, client):
        mock_rsvp.return_value = (
            {"id": "uuid-1", "rsvps": [1, 2], "status": "active", "min_group_size": 2},
            None,
        )
        resp = client.post('/api/signals/uuid-1/rsvp', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["data"]["status"] == "active"
