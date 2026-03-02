"""Tests for api/notifications.py endpoints."""

import json
from unittest.mock import patch
from OrbitServer.utils.auth import create_access_token


def auth_header(user_id=1):
    token = create_access_token(user_id)
    return {"Authorization": f"Bearer {token}"}


class TestGetNotifications:
    def test_rejects_unauthenticated(self, client):
        resp = client.get('/api/notifications')
        assert resp.status_code == 401

    @patch('OrbitServer.api.notifications.count_unread_notifications', return_value=2)
    @patch('OrbitServer.api.notifications.list_notifications')
    def test_returns_notifications(self, mock_list, mock_count, client):
        mock_list.return_value = [
            {'id': '1', 'type': 'pod_join', 'title': 'New member', 'body': 'Alex joined', 'read': False},
            {'id': '2', 'type': 'chat_message', 'title': 'Alex', 'body': 'Hey!', 'read': True},
        ]
        resp = client.get('/api/notifications', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body['success'] is True
        assert len(body['data']['notifications']) == 2
        assert body['data']['unread_count'] == 2

    @patch('OrbitServer.api.notifications.count_unread_notifications', return_value=0)
    @patch('OrbitServer.api.notifications.list_notifications', return_value=[])
    def test_returns_empty(self, mock_list, mock_count, client):
        resp = client.get('/api/notifications', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body['data']['notifications'] == []
        assert body['data']['unread_count'] == 0


class TestMarkRead:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/notifications/read', json={'notification_ids': ['1']})
        assert resp.status_code == 401

    def test_rejects_missing_ids(self, client):
        resp = client.post('/api/notifications/read', headers=auth_header(), json={})
        assert resp.status_code == 400

    def test_rejects_empty_ids(self, client):
        resp = client.post('/api/notifications/read', headers=auth_header(),
                           json={'notification_ids': []})
        assert resp.status_code == 400

    @patch('OrbitServer.api.notifications.mark_notifications_read')
    def test_marks_read(self, mock_mark, client):
        resp = client.post('/api/notifications/read', headers=auth_header(),
                           json={'notification_ids': ['1', '2']})
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body['success'] is True
        mock_mark.assert_called_once_with(1, ['1', '2'])


class TestMarkAllRead:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/notifications/read-all')
        assert resp.status_code == 401

    @patch('OrbitServer.api.notifications.mark_all_notifications_read')
    def test_marks_all_read(self, mock_mark, client):
        resp = client.post('/api/notifications/read-all', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body['success'] is True
        mock_mark.assert_called_once_with(1)


class TestUnreadCount:
    def test_rejects_unauthenticated(self, client):
        resp = client.get('/api/notifications/unread-count')
        assert resp.status_code == 401

    @patch('OrbitServer.api.notifications.count_unread_notifications', return_value=5)
    def test_returns_count(self, mock_count, client):
        resp = client.get('/api/notifications/unread-count', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body['data']['unread_count'] == 5


class TestDeviceToken:
    def test_register_rejects_unauthenticated(self, client):
        resp = client.post('/api/devices', json={'token': 'abc123'})
        assert resp.status_code == 401

    def test_register_rejects_empty_token(self, client):
        resp = client.post('/api/devices', headers=auth_header(), json={'token': ''})
        assert resp.status_code == 400

    @patch('OrbitServer.api.notifications.save_device_token')
    def test_register_success(self, mock_save, client):
        mock_save.return_value = {'id': '1', 'user_id': 1, 'token': 'abc123'}
        resp = client.post('/api/devices', headers=auth_header(), json={'token': 'abc123'})
        body = json.loads(resp.data)
        assert resp.status_code == 201
        assert body['success'] is True
        mock_save.assert_called_once_with(1, 'abc123')

    def test_unregister_rejects_unauthenticated(self, client):
        resp = client.delete('/api/devices', json={'token': 'abc123'})
        assert resp.status_code == 401

    @patch('OrbitServer.api.notifications.delete_device_token')
    def test_unregister_success(self, mock_delete, client):
        resp = client.delete('/api/devices', headers=auth_header(), json={'token': 'abc123'})
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body['success'] is True
        mock_delete.assert_called_once_with('abc123')
