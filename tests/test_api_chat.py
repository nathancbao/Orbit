"""Tests for api/chat.py message reaction / pin / delete endpoints."""

import json
from unittest.mock import patch
from OrbitServer.utils.auth import create_access_token


def auth_header(user_id=1):
    token = create_access_token(user_id)
    return {"Authorization": f"Bearer {token}"}


class TestReactToMessage:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/pods/pod-1/messages/msg-1/react',
                           json={"reaction": "thumbs_up"})
        assert resp.status_code == 401

    @patch('OrbitServer.api.chat.react_to_message')
    def test_react_success(self, mock_react, client):
        mock_react.return_value = (
            {"id": "msg-1", "reactions": {"thumbs_up": [1], "thumbs_down": [], "heart": []}},
            None,
        )
        resp = client.post('/api/pods/pod-1/messages/msg-1/react',
                           headers=auth_header(), json={"reaction": "thumbs_up"})
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["data"]["reactions"]["thumbs_up"] == [1]

    @patch('OrbitServer.api.chat.react_to_message')
    def test_react_invalid_emoji(self, mock_react, client):
        mock_react.return_value = (None, "reaction must be one of: thumbs_up, thumbs_down, heart")
        resp = client.post('/api/pods/pod-1/messages/msg-1/react',
                           headers=auth_header(), json={"reaction": "fire"})
        assert resp.status_code == 400

    @patch('OrbitServer.api.chat.react_to_message')
    def test_react_not_member(self, mock_react, client):
        mock_react.return_value = (None, "You are not a member of this pod")
        resp = client.post('/api/pods/pod-1/messages/msg-1/react',
                           headers=auth_header(), json={"reaction": "heart"})
        assert resp.status_code == 403

    @patch('OrbitServer.api.chat.react_to_message')
    def test_react_message_not_found(self, mock_react, client):
        mock_react.return_value = (None, "Message not found")
        resp = client.post('/api/pods/pod-1/messages/bad-id/react',
                           headers=auth_header(), json={"reaction": "heart"})
        assert resp.status_code == 404


class TestPinMessage:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/pods/pod-1/messages/msg-1/pin', json={"pinned": True})
        assert resp.status_code == 401

    def test_rejects_non_boolean_pinned(self, client):
        resp = client.post('/api/pods/pod-1/messages/msg-1/pin',
                           headers=auth_header(), json={"pinned": "yes"})
        assert resp.status_code == 400

    @patch('OrbitServer.api.chat.set_message_pinned')
    def test_pin_success(self, mock_pin, client):
        mock_pin.return_value = ({"id": "msg-1", "pinned": True}, None)
        resp = client.post('/api/pods/pod-1/messages/msg-1/pin',
                           headers=auth_header(), json={"pinned": True})
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["data"]["pinned"] is True

    @patch('OrbitServer.api.chat.set_message_pinned')
    def test_pin_defaults_to_true(self, mock_pin, client):
        mock_pin.return_value = ({"id": "msg-1", "pinned": True}, None)
        resp = client.post('/api/pods/pod-1/messages/msg-1/pin',
                           headers=auth_header(), json={})
        assert resp.status_code == 200
        mock_pin.assert_called_once()
        assert mock_pin.call_args[0][3] is True

    @patch('OrbitServer.api.chat.set_message_pinned')
    def test_pin_requires_leader(self, mock_pin, client):
        mock_pin.return_value = (None, "Only the pod leader can pin messages")
        resp = client.post('/api/pods/pod-1/messages/msg-1/pin',
                           headers=auth_header(2), json={"pinned": True})
        assert resp.status_code == 403


class TestDeleteMessage:
    def test_rejects_unauthenticated(self, client):
        resp = client.delete('/api/pods/pod-1/messages/msg-1')
        assert resp.status_code == 401

    @patch('OrbitServer.api.chat.delete_message')
    def test_delete_success(self, mock_delete, client):
        mock_delete.return_value = (True, None)
        resp = client.delete('/api/pods/pod-1/messages/msg-1', headers=auth_header())
        assert resp.status_code == 200

    @patch('OrbitServer.api.chat.delete_message')
    def test_delete_only_own_messages(self, mock_delete, client):
        mock_delete.return_value = (False, "You can only delete your own messages")
        resp = client.delete('/api/pods/pod-1/messages/msg-1', headers=auth_header())
        assert resp.status_code == 403

    @patch('OrbitServer.api.chat.delete_message')
    def test_delete_message_not_found(self, mock_delete, client):
        mock_delete.return_value = (False, "Message not found")
        resp = client.delete('/api/pods/pod-1/messages/bad-id', headers=auth_header())
        assert resp.status_code == 404


class TestReactionServiceLogic:
    """Service-level tests for react/pin/delete permission + toggle logic."""

    def _pod(self):
        return {"id": "pod-1", "member_ids": [1, 2, 3]}

    def _msg(self, user_id=2):
        return {
            "id": "msg-1", "pod_id": "pod-1", "user_id": user_id,
            "reactions": {"thumbs_up": [], "thumbs_down": [], "heart": []},
            "pinned": False,
        }

    @patch('OrbitServer.services.chat_service.transactional_message_update')
    @patch('OrbitServer.services.chat_service.get_chat_message')
    @patch('OrbitServer.services.chat_service.get_pod')
    def test_react_toggles_user(self, mock_pod, mock_msg, mock_txn, client):
        mock_pod.return_value = self._pod()
        mock_msg.return_value = self._msg()

        captured = {}

        def fake_txn(message_id, fn):
            entity = {"reactions": {"thumbs_up": [2], "thumbs_down": [], "heart": []}}
            fn(entity)
            captured.update(entity)
            return None, entity

        mock_txn.side_effect = fake_txn

        from OrbitServer.services.chat_service import react_to_message
        msg, err = react_to_message("pod-1", "msg-1", 1, "thumbs_up")
        assert err is None
        assert captured["reactions"]["thumbs_up"] == [2, 1]

        # Reacting again removes the user (toggle off)
        msg, err = react_to_message("pod-1", "msg-1", 2, "thumbs_up")
        assert err is None
        assert captured["reactions"]["thumbs_up"] == [1] or 2 not in captured["reactions"]["thumbs_up"]

    @patch('OrbitServer.services.chat_service.get_chat_message')
    @patch('OrbitServer.services.chat_service.get_pod')
    def test_react_rejects_invalid_reaction(self, mock_pod, mock_msg, client):
        from OrbitServer.services.chat_service import react_to_message
        msg, err = react_to_message("pod-1", "msg-1", 1, "fire")
        assert msg is None
        assert "reaction must be one of" in err

    @patch('OrbitServer.services.chat_service.get_chat_message')
    @patch('OrbitServer.services.chat_service.get_pod')
    def test_pin_rejects_non_leader(self, mock_pod, mock_msg, client):
        mock_pod.return_value = self._pod()
        mock_msg.return_value = self._msg()
        from OrbitServer.services.chat_service import set_message_pinned
        msg, err = set_message_pinned("pod-1", "msg-1", 2, True)
        assert msg is None
        assert "leader" in err.lower()

    @patch('OrbitServer.services.chat_service.delete_chat_message')
    @patch('OrbitServer.services.chat_service.get_chat_message')
    @patch('OrbitServer.services.chat_service.get_pod')
    def test_delete_rejects_other_users_message(self, mock_pod, mock_msg, mock_del, client):
        mock_pod.return_value = self._pod()
        mock_msg.return_value = self._msg(user_id=2)
        from OrbitServer.services.chat_service import delete_message
        ok, err = delete_message("pod-1", "msg-1", 1)
        assert ok is False
        assert "your own" in err.lower()
        mock_del.assert_not_called()

    @patch('OrbitServer.services.chat_service.delete_chat_message')
    @patch('OrbitServer.services.chat_service.get_chat_message')
    @patch('OrbitServer.services.chat_service.get_pod')
    def test_delete_own_message(self, mock_pod, mock_msg, mock_del, client):
        mock_pod.return_value = self._pod()
        mock_msg.return_value = self._msg(user_id=1)
        from OrbitServer.services.chat_service import delete_message
        ok, err = delete_message("pod-1", "msg-1", 1)
        assert ok is True
        assert err is None
        mock_del.assert_called_once_with("msg-1")
