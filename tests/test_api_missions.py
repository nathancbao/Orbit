"""Tests for api/missions.py endpoints."""

import json
from unittest.mock import patch
from OrbitServer.utils.auth import create_access_token


def auth_header(user_id=1):
    token = create_access_token(user_id)
    return {"Authorization": f"Bearer {token}"}


class TestCreateMission:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/missions/',
                           json={"title": "Hike", "description": "Let's hike"})
        assert resp.status_code == 401

    @staticmethod
    def _valid_data(**overrides):
        from datetime import datetime, timedelta
        base = {
            "title": "Hike",
            "description": "Trail run",
            "start_time": (datetime.utcnow() + timedelta(hours=1)).isoformat() + "Z",
            "end_time": (datetime.utcnow() + timedelta(hours=3)).isoformat() + "Z",
        }
        base.update(overrides)
        return base

    def test_rejects_missing_title(self, client):
        data = self._valid_data()
        del data["title"]
        resp = client.post('/api/missions/',
                           headers=auth_header(),
                           json=data)
        assert resp.status_code == 400

    def test_rejects_missing_description(self, client):
        data = self._valid_data()
        del data["description"]
        resp = client.post('/api/missions/',
                           headers=auth_header(),
                           json=data)
        assert resp.status_code == 400

    @patch('OrbitServer.api.missions.create_mission')
    def test_creates_mission(self, mock_create, client):
        mock_create.return_value = (
            {"id": 1, "title": "Hike", "hard_rsvp_count": 0, "soft_rsvp_count": 0},
            None
        )
        resp = client.post('/api/missions/',
                           headers=auth_header(),
                           json=self._valid_data())
        body = json.loads(resp.data)
        assert resp.status_code == 201
        assert body["success"] is True

    def test_rejects_long_title(self, client):
        resp = client.post('/api/missions/',
                           headers=auth_header(),
                           json=self._valid_data(title="x" * 201))
        assert resp.status_code == 400


class TestListMissions:
    @patch('OrbitServer.api.missions.list_missions')
    def test_lists_missions(self, mock_list, client):
        mock_list.return_value = ([{"id": 1, "title": "Hike"}], None)
        resp = client.get('/api/missions/')
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True

    @patch('OrbitServer.api.missions.list_missions')
    def test_lists_with_tag_filter(self, mock_list, client):
        mock_list.return_value = ([], None)
        resp = client.get('/api/missions/?tag=outdoors')
        assert resp.status_code == 200
        call_args = mock_list.call_args[0][0]
        assert call_args['tag'] == 'outdoors'


class TestRsvpMission:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/missions/1/rsvp')
        assert resp.status_code == 401

    @patch('OrbitServer.api.missions.rsvp_mission')
    def test_rsvp_success(self, mock_rsvp, client):
        mock_rsvp.return_value = ({"message": "RSVPed"}, None)
        resp = client.post('/api/missions/1/rsvp', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True

    @patch('OrbitServer.api.missions.rsvp_mission')
    def test_rsvp_already_exists(self, mock_rsvp, client):
        mock_rsvp.return_value = (None, "Already RSVPed")
        resp = client.post('/api/missions/1/rsvp', headers=auth_header())
        assert resp.status_code == 400
