"""Tests for api/users.py endpoints — auth-protected routes."""

import json
from unittest.mock import patch
from OrbitServer.utils.auth import create_access_token


def auth_header(user_id=1):
    """Create a valid Bearer token header for testing."""
    token = create_access_token(user_id)
    return {"Authorization": f"Bearer {token}"}


class TestGetMe:
    def test_rejects_unauthenticated(self, client):
        resp = client.get('/api/users/me')
        assert resp.status_code == 401

    def test_rejects_bad_token(self, client):
        resp = client.get('/api/users/me',
                          headers={"Authorization": "Bearer bad-token"})
        assert resp.status_code == 401

    @patch('OrbitServer.api.users.get_user_profile')
    def test_returns_profile(self, mock_get_profile, client):
        mock_get_profile.return_value = (
            {"profile": {"name": "Test"}, "profile_complete": True},
            None
        )
        resp = client.get('/api/users/me', headers=auth_header(1))
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True

    @patch('OrbitServer.api.users.get_user_profile')
    def test_returns_404_when_missing(self, mock_get_profile, client):
        mock_get_profile.return_value = (None, "Profile not found")
        resp = client.get('/api/users/me', headers=auth_header(1))
        assert resp.status_code == 404


class TestUpdateMe:
    def test_rejects_unauthenticated(self, client):
        resp = client.put('/api/users/me', json={"name": "Test"})
        assert resp.status_code == 401

    def test_rejects_empty_body(self, client):
        resp = client.put('/api/users/me',
                          headers=auth_header(),
                          content_type='application/json',
                          data='{}')
        assert resp.status_code == 400

    @patch('OrbitServer.api.users.update_user_profile')
    def test_rejects_invalid_profile_data(self, mock_update, client):
        resp = client.put('/api/users/me',
                          headers=auth_header(),
                          json={"age": 5})  # Too young
        assert resp.status_code == 400

    @patch('OrbitServer.api.users.update_user_profile')
    def test_updates_valid_profile(self, mock_update, client):
        mock_update.return_value = (
            {"profile": {"name": "Updated"}, "profile_complete": True},
            None
        )
        resp = client.put('/api/users/me',
                          headers=auth_header(),
                          json={"name": "Updated"})
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True


class TestGetPublicUser:
    def test_rejects_unauthenticated(self, client):
        # The endpoint used to be public and leak emails; it now requires auth.
        resp = client.get('/api/users/42')
        assert resp.status_code == 401

    @patch('OrbitServer.api.users.get_user_profile')
    def test_other_user_omits_private_fields(self, mock_get_profile, client):
        mock_get_profile.return_value = (
            {"profile": {"name": "Public User"}, "profile_complete": True},
            None
        )
        resp = client.get('/api/users/42', headers=auth_header(1))
        assert resp.status_code == 200
        # Caller (1) is viewing another user (42): private fields must be stripped.
        mock_get_profile.assert_called_once_with('42', include_private=False)

    @patch('OrbitServer.api.users.get_user_profile')
    def test_self_via_id_includes_private_fields(self, mock_get_profile, client):
        mock_get_profile.return_value = (
            {"profile": {"name": "Me", "email": "me@x.edu"}, "profile_complete": True},
            None
        )
        resp = client.get('/api/users/1', headers=auth_header(1))
        assert resp.status_code == 200
        mock_get_profile.assert_called_once_with('1', include_private=True)

    @patch('OrbitServer.api.users.get_user_profile')
    def test_returns_404_for_missing_user(self, mock_get_profile, client):
        mock_get_profile.return_value = (None, "User not found")
        resp = client.get('/api/users/999', headers=auth_header(1))
        assert resp.status_code == 404
