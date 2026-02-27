"""Tests for api/events.py endpoints."""

import json
from unittest.mock import patch
from OrbitServer.utils.auth import create_access_token


def auth_header(user_id=1):
    token = create_access_token(user_id)
    return {"Authorization": f"Bearer {token}"}


class TestListEvents:
    def test_rejects_unauthenticated(self, client):
        resp = client.get('/api/events')
        assert resp.status_code == 401

    @patch('OrbitServer.api.events.get_user_pod_for_event')
    @patch('OrbitServer.api.events.list_event_pods')
    @patch('OrbitServer.api.events.get_events_for_user')
    def test_returns_events(self, mock_list, mock_pods, mock_user_pod, client):
        mock_list.return_value = [{"id": 1, "title": "Hike", "max_pod_size": 4}]
        mock_user_pod.return_value = None
        mock_pods.return_value = []
        resp = client.get('/api/events', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
        assert len(body["data"]) == 1

    @patch('OrbitServer.api.events.get_user_pod_for_event')
    @patch('OrbitServer.api.events.list_event_pods')
    @patch('OrbitServer.api.events.get_events_for_user')
    def test_annotates_user_pod_status(self, mock_list, mock_pods, mock_user_pod, client):
        mock_list.return_value = [{"id": 1, "title": "Hike", "max_pod_size": 4}]
        mock_user_pod.return_value = {"id": "pod-abc"}
        resp = client.get('/api/events', headers=auth_header())
        body = json.loads(resp.data)
        assert body["data"][0]["user_pod_status"] == "in_pod"


class TestSuggestedEvents:
    def test_rejects_unauthenticated(self, client):
        resp = client.get('/api/events/suggested')
        assert resp.status_code == 401

    @patch('OrbitServer.api.events.get_suggested_events')
    def test_returns_suggestions(self, mock_suggest, client):
        mock_suggest.return_value = [{"id": 2, "title": "Coffee Chat", "suggestion_reason": "You like coffee"}]
        resp = client.get('/api/events/suggested', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
        assert len(body["data"]) == 1

    @patch('OrbitServer.api.events.get_suggested_events')
    def test_returns_empty_when_none(self, mock_suggest, client):
        mock_suggest.return_value = []
        resp = client.get('/api/events/suggested', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["data"] == []


class TestCreateEvent:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/events', json={"title": "Hike", "description": "Fun"})
        assert resp.status_code == 401

    def test_rejects_missing_title(self, client):
        resp = client.post('/api/events', headers=auth_header(), json={"description": "Fun"})
        assert resp.status_code == 400

    def test_rejects_missing_description(self, client):
        resp = client.post('/api/events', headers=auth_header(), json={"title": "Hike"})
        assert resp.status_code == 400

    def test_rejects_long_title(self, client):
        resp = client.post('/api/events', headers=auth_header(),
                           json={"title": "x" * 201, "description": "Fun"})
        assert resp.status_code == 400

    @patch('OrbitServer.api.events.create_new_event')
    def test_creates_event(self, mock_create, client):
        mock_create.return_value = {"id": 1, "title": "Hike", "status": "open"}
        resp = client.post('/api/events', headers=auth_header(),
                           json={"title": "Hike", "description": "Trail run"})
        body = json.loads(resp.data)
        assert resp.status_code == 201
        assert body["success"] is True

    @patch('OrbitServer.api.events.create_new_event')
    def test_creates_event_with_tags(self, mock_create, client):
        mock_create.return_value = {"id": 1, "title": "Hike", "tags": ["hiking", "outdoors"]}
        resp = client.post('/api/events', headers=auth_header(),
                           json={"title": "Hike", "description": "Trail run", "tags": ["hiking", "outdoors"]})
        assert resp.status_code == 201

    @patch('OrbitServer.api.events.get_or_create_event_embedding')
    @patch('OrbitServer.api.events.create_new_event')
    def test_triggers_embedding_on_create(self, mock_create, mock_embed, client):
        mock_create.return_value = {"id": 5, "title": "Yoga", "status": "open"}
        mock_embed.return_value = None
        resp = client.post('/api/events', headers=auth_header(),
                           json={"title": "Yoga", "description": "Morning flow"})
        assert resp.status_code == 201


class TestJoinEvent:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/events/1/join')
        assert resp.status_code == 401

    @patch('OrbitServer.api.events.join_event')
    def test_join_success(self, mock_join, client):
        mock_join.return_value = ({"id": "pod-uuid", "event_id": 1, "member_ids": [1]}, None)
        resp = client.post('/api/events/1/join', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 201
        assert body["success"] is True

    @patch('OrbitServer.api.events.join_event')
    def test_join_event_not_found(self, mock_join, client):
        mock_join.return_value = (None, "Event not found")
        resp = client.post('/api/events/99/join', headers=auth_header())
        assert resp.status_code == 400

    @patch('OrbitServer.api.events.join_event')
    def test_join_closed_event(self, mock_join, client):
        mock_join.return_value = (None, "This event is no longer accepting new members")
        resp = client.post('/api/events/1/join', headers=auth_header())
        assert resp.status_code == 400


class TestLeaveEvent:
    def test_rejects_unauthenticated(self, client):
        resp = client.delete('/api/events/1/leave')
        assert resp.status_code == 401

    @patch('OrbitServer.api.events.leave_event')
    def test_leave_success(self, mock_leave, client):
        mock_leave.return_value = (True, None)
        resp = client.delete('/api/events/1/leave', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True

    @patch('OrbitServer.api.events.leave_event')
    def test_leave_not_in_pod(self, mock_leave, client):
        mock_leave.return_value = (False, "You are not in a pod for this event")
        resp = client.delete('/api/events/1/leave', headers=auth_header())
        assert resp.status_code == 400


class TestSkipEvent:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/events/1/skip')
        assert resp.status_code == 401

    @patch('OrbitServer.api.events.record_event_action')
    @patch('OrbitServer.api.events.get_event_detail')
    def test_skip_success(self, mock_get, mock_record, client):
        mock_get.return_value = {"id": 1, "title": "Hike"}
        resp = client.post('/api/events/1/skip', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
        mock_record.assert_called_once()

    @patch('OrbitServer.api.events.get_event_detail')
    def test_skip_not_found(self, mock_get, client):
        mock_get.return_value = None
        resp = client.post('/api/events/99/skip', headers=auth_header())
        assert resp.status_code == 404
