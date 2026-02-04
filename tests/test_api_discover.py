"""Tests for api/discover.py endpoints — all require auth."""

import json
from unittest.mock import patch
from OrbitServer.utils.auth import create_access_token


def auth_header(user_id=1):
    token = create_access_token(user_id)
    return {"Authorization": f"Bearer {token}"}


class TestDiscoverUsers:
    def test_rejects_unauthenticated(self, client):
        resp = client.get('/api/discover/users')
        assert resp.status_code == 401

    @patch('OrbitServer.api.discover.suggested_users')
    def test_returns_suggestions(self, mock_suggest, client):
        mock_suggest.return_value = [
            {"name": "Alice", "interests": ["hiking"]},
            {"name": "Bob", "interests": ["music"]},
        ]
        resp = client.get('/api/discover/users', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
        assert len(body["data"]) == 2

    @patch('OrbitServer.api.discover.suggested_users')
    def test_returns_empty_list(self, mock_suggest, client):
        mock_suggest.return_value = []
        resp = client.get('/api/discover/users', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["data"] == []


class TestDiscoverCrews:
    def test_rejects_unauthenticated(self, client):
        resp = client.get('/api/discover/crews')
        assert resp.status_code == 401

    @patch('OrbitServer.api.discover.suggested_crews')
    def test_returns_crew_suggestions(self, mock_suggest, client):
        mock_suggest.return_value = [{"name": "Study Crew", "match_score": 3}]
        resp = client.get('/api/discover/crews', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True


class TestDiscoverMissions:
    def test_rejects_unauthenticated(self, client):
        resp = client.get('/api/discover/missions')
        assert resp.status_code == 401

    @patch('OrbitServer.api.discover.suggested_missions')
    def test_returns_mission_suggestions(self, mock_suggest, client):
        mock_suggest.return_value = [{"title": "Hike", "match_score": 2}]
        resp = client.get('/api/discover/missions', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
