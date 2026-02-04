"""Tests for api/crews.py endpoints."""

import json
from unittest.mock import patch
from OrbitServer.utils.auth import create_access_token


def auth_header(user_id=1):
    token = create_access_token(user_id)
    return {"Authorization": f"Bearer {token}"}


class TestCreateCrew:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/crews/', json={"name": "Study Group"})
        assert resp.status_code == 401

    def test_rejects_missing_name(self, client):
        resp = client.post('/api/crews/', headers=auth_header(), json={})
        assert resp.status_code == 400

    @patch('OrbitServer.api.crews.create_crew')
    def test_creates_crew(self, mock_create, client):
        mock_create.return_value = (
            {"id": 1, "name": "Study Group", "member_count": 1},
            None
        )
        resp = client.post('/api/crews/',
                           headers=auth_header(),
                           json={"name": "Study Group"})
        body = json.loads(resp.data)
        assert resp.status_code == 201
        assert body["success"] is True

    def test_rejects_long_name(self, client):
        resp = client.post('/api/crews/',
                           headers=auth_header(),
                           json={"name": "x" * 101})
        assert resp.status_code == 400


class TestListCrews:
    @patch('OrbitServer.api.crews.list_crews')
    def test_lists_crews(self, mock_list, client):
        mock_list.return_value = ([{"id": 1, "name": "Crew A"}], None)
        resp = client.get('/api/crews/')
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True

    @patch('OrbitServer.api.crews.list_crews')
    def test_lists_with_tag_filter(self, mock_list, client):
        mock_list.return_value = ([], None)
        resp = client.get('/api/crews/?tag=hiking')
        assert resp.status_code == 200
        # Verify the tag filter was passed through
        call_args = mock_list.call_args[0][0]
        assert call_args['tag'] == 'hiking'


class TestJoinCrew:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/crews/1/join')
        assert resp.status_code == 401

    @patch('OrbitServer.api.crews.join_crew')
    def test_join_success(self, mock_join, client):
        mock_join.return_value = ({"message": "Joined"}, None)
        resp = client.post('/api/crews/1/join', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True

    @patch('OrbitServer.api.crews.join_crew')
    def test_join_already_member(self, mock_join, client):
        mock_join.return_value = (None, "Already a member")
        resp = client.post('/api/crews/1/join', headers=auth_header())
        assert resp.status_code == 400


class TestLeaveCrew:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/crews/1/leave')
        assert resp.status_code == 401

    @patch('OrbitServer.api.crews.leave_crew')
    def test_leave_success(self, mock_leave, client):
        mock_leave.return_value = ({"message": "Left"}, None)
        resp = client.post('/api/crews/1/leave', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True

    @patch('OrbitServer.api.crews.leave_crew')
    def test_leave_not_member(self, mock_leave, client):
        mock_leave.return_value = (None, "Not a member")
        resp = client.post('/api/crews/1/leave', headers=auth_header())
        assert resp.status_code == 400
