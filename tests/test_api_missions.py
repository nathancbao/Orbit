"""Tests for api/missions.py endpoints."""

import json
from unittest.mock import patch
from OrbitServer.utils.auth import create_access_token


def auth_header(user_id=1):
    token = create_access_token(user_id)
    return {"Authorization": f"Bearer {token}"}


VALID_MISSION = {
    "title": "Sports",
    "activity_category": "Sports",
    "custom_activity_name": None,
    "min_group_size": 2,
    "max_group_size": 6,
    "availability": [
        {"date": "2026-03-01", "time_blocks": ["morning", "afternoon"]}
    ],
    "description": "pickup basketball",
}


# ── GET /api/missions ─────────────────────────────────────────────────────────

class TestListMissions:
    def test_rejects_unauthenticated(self, client):
        resp = client.get('/api/missions')
        assert resp.status_code == 401

    @patch('OrbitServer.api.missions.get_user_missions')
    def test_returns_user_missions(self, mock_get, client):
        mock_get.return_value = ([
            {"id": "uuid-1", "title": "Sports", "status": "pending"},
        ], None)
        resp = client.get('/api/missions', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
        assert len(body["data"]) == 1

    @patch('OrbitServer.api.missions.get_user_missions')
    def test_returns_only_own_missions(self, mock_get, client):
        """Service layer receives g.user_id — verify it's called with the right user."""
        mock_get.return_value = ([], None)
        client.get('/api/missions', headers=auth_header(user_id=42))
        mock_get.assert_called_once_with(42)


# ── POST /api/missions ────────────────────────────────────────────────────────

class TestCreateMission:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/missions', json=VALID_MISSION)
        assert resp.status_code == 401

    @patch('OrbitServer.api.missions.create_new_mission')
    def test_creates_valid_mission(self, mock_create, client):
        mock_create.return_value = ({"id": "uuid-1", **VALID_MISSION, "status": "pending"}, None)
        resp = client.post('/api/missions', headers=auth_header(), json=VALID_MISSION)
        body = json.loads(resp.data)
        assert resp.status_code == 201
        assert body["success"] is True

    def test_rejects_missing_category(self, client):
        bad = {**VALID_MISSION}
        del bad["activity_category"]
        resp = client.post('/api/missions', headers=auth_header(), json=bad)
        assert resp.status_code == 400

    def test_rejects_invalid_category(self, client):
        bad = {**VALID_MISSION, "activity_category": "NotACategory"}
        resp = client.post('/api/missions', headers=auth_header(), json=bad)
        assert resp.status_code == 400

    def test_rejects_empty_availability(self, client):
        bad = {**VALID_MISSION, "availability": []}
        resp = client.post('/api/missions', headers=auth_header(), json=bad)
        assert resp.status_code == 400

    def test_rejects_min_greater_than_max(self, client):
        bad = {**VALID_MISSION, "min_group_size": 8, "max_group_size": 3}
        resp = client.post('/api/missions', headers=auth_header(), json=bad)
        assert resp.status_code == 400

    def test_rejects_invalid_time_block(self, client):
        bad = {**VALID_MISSION, "availability": [
            {"date": "2026-03-01", "time_blocks": ["midnight"]}
        ]}
        resp = client.post('/api/missions', headers=auth_header(), json=bad)
        assert resp.status_code == 400

    def test_custom_category_requires_name(self, client):
        bad = {**VALID_MISSION, "activity_category": "Custom", "custom_activity_name": None}
        resp = client.post('/api/missions', headers=auth_header(), json=bad)
        assert resp.status_code == 400


# ── DELETE /api/missions/<id> ─────────────────────────────────────────────────

class TestDeleteMission:
    def test_rejects_unauthenticated(self, client):
        resp = client.delete('/api/missions/uuid-1')
        assert resp.status_code == 401

    @patch('OrbitServer.api.missions.remove_mission')
    def test_deletes_own_mission(self, mock_remove, client):
        mock_remove.return_value = (True, None, None)
        resp = client.delete('/api/missions/uuid-1', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True

    @patch('OrbitServer.api.missions.remove_mission')
    def test_rejects_non_creator(self, mock_remove, client):
        mock_remove.return_value = (False, "Only the creator can delete this mission", 403)
        resp = client.delete('/api/missions/uuid-1', headers=auth_header())
        assert resp.status_code == 403

    @patch('OrbitServer.api.missions.remove_mission')
    def test_404_for_unknown_mission(self, mock_remove, client):
        mock_remove.return_value = (False, "Mission not found", 404)
        resp = client.delete('/api/missions/nonexistent', headers=auth_header())
        assert resp.status_code == 404


# ── GET /api/missions/discover ────────────────────────────────────────────────

class TestDiscoverMissions:
    def test_rejects_unauthenticated(self, client):
        resp = client.get('/api/missions/discover')
        assert resp.status_code == 401

    @patch('OrbitServer.api.missions.get_all_missions')
    def test_returns_missions(self, mock_discover, client):
        mock_discover.return_value = ([
            {"id": "uuid-1", "title": "Sports", "status": "pending"},
            {"id": "uuid-2", "title": "Food", "status": "pending"},
        ], None)
        resp = client.get('/api/missions/discover', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
        assert len(body["data"]) == 2

    @patch('OrbitServer.api.missions.get_all_missions')
    def test_returns_empty_list(self, mock_discover, client):
        mock_discover.return_value = ([], None)
        resp = client.get('/api/missions/discover', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["data"] == []


# ── POST /api/missions/<id>/rsvp ─────────────────────────────────────────────

class TestRsvpMission:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/missions/uuid-1/rsvp')
        assert resp.status_code == 401

    @patch('OrbitServer.api.missions.rsvp_mission')
    def test_rsvp_success(self, mock_rsvp, client):
        mock_rsvp.return_value = (
            {"id": "uuid-1", "rsvps": [1], "status": "pending", "min_group_size": 2},
            None,
        )
        resp = client.post('/api/missions/uuid-1/rsvp', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True

    @patch('OrbitServer.api.missions.rsvp_mission')
    def test_rsvp_duplicate_rejected(self, mock_rsvp, client):
        mock_rsvp.return_value = (None, "You have already RSVP'd to this signal")
        resp = client.post('/api/missions/uuid-1/rsvp', headers=auth_header())
        assert resp.status_code == 409

    @patch('OrbitServer.api.missions.rsvp_mission')
    def test_rsvp_not_found(self, mock_rsvp, client):
        mock_rsvp.return_value = (None, "Mission not found")
        resp = client.post('/api/missions/nonexistent/rsvp', headers=auth_header())
        assert resp.status_code == 404

    @patch('OrbitServer.api.missions.rsvp_mission')
    def test_rsvp_activates_at_min_group_size(self, mock_rsvp, client):
        mock_rsvp.return_value = (
            {"id": "uuid-1", "rsvps": [1, 2], "status": "active", "min_group_size": 2},
            None,
        )
        resp = client.post('/api/missions/uuid-1/rsvp', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["data"]["status"] == "active"
