"""Tests for api/auth.py endpoints using Flask test client with mocked Datastore."""

import json
from unittest.mock import patch, MagicMock


class TestSendCode:
    def test_valid_edu_email(self, client):
        with patch('OrbitServer.services.auth_service.store_verification_code'):
            resp = client.post('/api/auth/send-code',
                               json={"email": "test@university.edu"})
            body = json.loads(resp.data)
            assert resp.status_code == 200
            assert body["success"] is True

    def test_rejects_non_edu_email(self, client):
        resp = client.post('/api/auth/send-code',
                           json={"email": "test@gmail.com"})
        body = json.loads(resp.data)
        assert resp.status_code == 400
        assert body["success"] is False

    def test_rejects_empty_email(self, client):
        resp = client.post('/api/auth/send-code', json={"email": ""})
        assert resp.status_code == 400

    def test_rejects_missing_email(self, client):
        resp = client.post('/api/auth/send-code', json={})
        assert resp.status_code == 400

    def test_rejects_no_body(self, client):
        resp = client.post('/api/auth/send-code')
        assert resp.status_code == 400


class TestVerifyCode:
    def test_rejects_missing_fields(self, client):
        resp = client.post('/api/auth/verify-code', json={})
        body = json.loads(resp.data)
        assert resp.status_code == 400
        assert body["success"] is False

    def test_rejects_missing_code(self, client):
        resp = client.post('/api/auth/verify-code',
                           json={"email": "test@university.edu"})
        assert resp.status_code == 400

    def test_rejects_missing_email(self, client):
        resp = client.post('/api/auth/verify-code',
                           json={"code": "123456"})
        assert resp.status_code == 400

    @patch('OrbitServer.services.auth_service.get_user_by_email')
    @patch('OrbitServer.services.auth_service.create_user')
    @patch('OrbitServer.services.auth_service.store_refresh_token')
    def test_demo_bypass_new_user(self, mock_store_rt, mock_create, mock_get_user, client):
        mock_get_user.return_value = None
        mock_create.return_value = {'id': 1, 'email': 'test@university.edu'}

        resp = client.post('/api/auth/verify-code',
                           json={"email": "test@university.edu", "code": "123456"})
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
        assert "access_token" in body["data"]
        assert "refresh_token" in body["data"]
        assert body["data"]["is_new_user"] is True

    @patch('OrbitServer.services.auth_service.get_user_by_email')
    @patch('OrbitServer.services.auth_service.store_refresh_token')
    def test_demo_bypass_existing_user(self, mock_store_rt, mock_get_user, client):
        mock_get_user.return_value = {'id': 5, 'email': 'test@university.edu'}

        resp = client.post('/api/auth/verify-code',
                           json={"email": "test@university.edu", "code": "123456"})
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["data"]["is_new_user"] is False
        assert body["data"]["user_id"] == 5


class TestRefresh:
    def test_rejects_missing_refresh_token(self, client):
        resp = client.post('/api/auth/refresh', json={})
        body = json.loads(resp.data)
        assert resp.status_code == 400
        assert body["success"] is False

    @patch('OrbitServer.services.auth_service.get_refresh_token')
    def test_rejects_invalid_refresh_token(self, mock_get_rt, client):
        mock_get_rt.return_value = None
        resp = client.post('/api/auth/refresh',
                           json={"refresh_token": "bad-token"})
        assert resp.status_code == 401


class TestLogout:
    def test_rejects_missing_refresh_token(self, client):
        resp = client.post('/api/auth/logout', json={})
        assert resp.status_code == 400

    @patch('OrbitServer.services.auth_service.delete_refresh_token')
    def test_logout_success(self, mock_delete_rt, client):
        resp = client.post('/api/auth/logout',
                           json={"refresh_token": "some-token"})
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
        mock_delete_rt.assert_called_once_with("some-token")
