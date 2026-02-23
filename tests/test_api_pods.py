"""Tests for api/pods.py endpoints."""

import json
from unittest.mock import patch
from OrbitServer.utils.auth import create_access_token


def auth_header(user_id=1):
    token = create_access_token(user_id)
    return {"Authorization": f"Bearer {token}"}


class TestGetPod:
    def test_rejects_unauthenticated(self, client):
        resp = client.get('/api/pods/some-pod-id')
        assert resp.status_code == 401

    @patch('OrbitServer.api.pods.get_pod_with_members')
    def test_returns_pod(self, mock_get, client):
        mock_get.return_value = (
            {"id": "pod-1", "event_id": 1, "members": [{"user_id": 1, "name": "Alex"}]},
            None
        )
        resp = client.get('/api/pods/pod-1', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
        assert body["data"]["id"] == "pod-1"

    @patch('OrbitServer.api.pods.get_pod_with_members')
    def test_pod_not_found(self, mock_get, client):
        mock_get.return_value = (None, "Pod not found")
        resp = client.get('/api/pods/bad-id', headers=auth_header())
        assert resp.status_code == 404

    @patch('OrbitServer.api.pods.get_pod_with_members')
    def test_pod_not_member(self, mock_get, client):
        mock_get.return_value = (None, "You are not a member of this pod")
        resp = client.get('/api/pods/pod-1', headers=auth_header())
        assert resp.status_code == 403


class TestKickVote:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/pods/pod-1/kick', json={"target_user_id": 2})
        assert resp.status_code == 401

    def test_rejects_missing_target(self, client):
        resp = client.post('/api/pods/pod-1/kick', headers=auth_header(), json={})
        assert resp.status_code == 400

    @patch('OrbitServer.api.pods.vote_to_kick')
    def test_kick_vote_recorded(self, mock_kick, client):
        mock_kick.return_value = ({"id": "pod-1", "kick_votes": {"2": [1]}}, False, None)
        resp = client.post('/api/pods/pod-1/kick', headers=auth_header(),
                           json={"target_user_id": 2})
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["data"]["kicked"] is False
        assert "vote recorded" in body["data"]["message"].lower()

    @patch('OrbitServer.api.pods.vote_to_kick')
    def test_kick_executed(self, mock_kick, client):
        mock_kick.return_value = ({"id": "pod-1", "member_ids": [1, 3]}, True, None)
        resp = client.post('/api/pods/pod-1/kick', headers=auth_header(),
                           json={"target_user_id": 2})
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["data"]["kicked"] is True

    @patch('OrbitServer.api.pods.vote_to_kick')
    def test_kick_pod_not_found(self, mock_kick, client):
        mock_kick.return_value = (None, False, "Pod not found")
        resp = client.post('/api/pods/pod-1/kick', headers=auth_header(),
                           json={"target_user_id": 2})
        assert resp.status_code == 404

    @patch('OrbitServer.api.pods.vote_to_kick')
    def test_kick_not_member(self, mock_kick, client):
        mock_kick.return_value = (None, False, "You are not a member of this pod")
        resp = client.post('/api/pods/pod-1/kick', headers=auth_header(),
                           json={"target_user_id": 2})
        assert resp.status_code == 403


class TestConfirmAttendance:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/pods/pod-1/confirm-attendance')
        assert resp.status_code == 401

    @patch('OrbitServer.api.pods.confirm_attendance')
    def test_confirm_success(self, mock_confirm, client):
        mock_confirm.return_value = ({"id": "pod-1", "confirmed_attendees": [1]}, None)
        resp = client.post('/api/pods/pod-1/confirm-attendance', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
        assert "confirmed" in body["data"]["message"].lower()

    @patch('OrbitServer.api.pods.confirm_attendance')
    def test_confirm_not_member(self, mock_confirm, client):
        mock_confirm.return_value = (None, "You are not a member of this pod")
        resp = client.post('/api/pods/pod-1/confirm-attendance', headers=auth_header())
        assert resp.status_code == 403

    @patch('OrbitServer.api.pods.confirm_attendance')
    def test_confirm_pod_not_found(self, mock_confirm, client):
        mock_confirm.return_value = (None, "Pod not found")
        resp = client.post('/api/pods/pod-1/confirm-attendance', headers=auth_header())
        assert resp.status_code == 404
