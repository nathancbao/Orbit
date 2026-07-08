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
            {"id": "pod-1", "mission_id": 1, "members": [{"user_id": 1, "name": "Alex"}]},
            None, None
        )
        resp = client.get('/api/pods/pod-1', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
        assert body["data"]["id"] == "pod-1"

    @patch('OrbitServer.api.pods.get_pod_with_members')
    def test_pod_not_found(self, mock_get, client):
        mock_get.return_value = (None, "Pod not found", 404)
        resp = client.get('/api/pods/bad-id', headers=auth_header())
        assert resp.status_code == 404

    @patch('OrbitServer.api.pods.get_pod_with_members')
    def test_pod_not_member(self, mock_get, client):
        mock_get.return_value = (None, "You are not a member of this pod", 403)
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
        mock_kick.return_value = ({"id": "pod-1", "kick_votes": {"2": [1]}}, False, None, None)
        resp = client.post('/api/pods/pod-1/kick', headers=auth_header(),
                           json={"target_user_id": 2})
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["data"]["kicked"] is False
        assert "vote recorded" in body["data"]["message"].lower()

    @patch('OrbitServer.api.pods.vote_to_kick')
    def test_kick_executed(self, mock_kick, client):
        mock_kick.return_value = ({"id": "pod-1", "member_ids": [1, 3]}, True, None, None)
        resp = client.post('/api/pods/pod-1/kick', headers=auth_header(),
                           json={"target_user_id": 2})
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["data"]["kicked"] is True

    @patch('OrbitServer.api.pods.vote_to_kick')
    def test_kick_pod_not_found(self, mock_kick, client):
        mock_kick.return_value = (None, False, "Pod not found", 404)
        resp = client.post('/api/pods/pod-1/kick', headers=auth_header(),
                           json={"target_user_id": 2})
        assert resp.status_code == 404

    @patch('OrbitServer.api.pods.vote_to_kick')
    def test_kick_not_member(self, mock_kick, client):
        mock_kick.return_value = (None, False, "You are not a member of this pod", 403)
        resp = client.post('/api/pods/pod-1/kick', headers=auth_header(),
                           json={"target_user_id": 2})
        assert resp.status_code == 403


class TestConfirmAttendance:
    def test_rejects_unauthenticated(self, client):
        resp = client.post('/api/pods/pod-1/confirm-attendance')
        assert resp.status_code == 401

    @patch('OrbitServer.api.pods.confirm_attendance')
    def test_confirm_success(self, mock_confirm, client):
        mock_confirm.return_value = ({"id": "pod-1", "confirmed_attendees": [1]}, None, None)
        resp = client.post('/api/pods/pod-1/confirm-attendance', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["success"] is True
        assert "confirmed" in body["data"]["message"].lower()

    @patch('OrbitServer.api.pods.confirm_attendance')
    def test_confirm_not_member(self, mock_confirm, client):
        mock_confirm.return_value = (None, "You are not a member of this pod", 403)
        resp = client.post('/api/pods/pod-1/confirm-attendance', headers=auth_header())
        assert resp.status_code == 403

    @patch('OrbitServer.api.pods.confirm_attendance')
    def test_confirm_pod_not_found(self, mock_confirm, client):
        mock_confirm.return_value = (None, "Pod not found", 404)
        resp = client.post('/api/pods/pod-1/confirm-attendance', headers=auth_header())
        assert resp.status_code == 404


class TestDeletePod:
    def test_rejects_unauthenticated(self, client):
        resp = client.delete('/api/pods/pod-1')
        assert resp.status_code == 401

    @patch('OrbitServer.api.pods.delete_pod_as_leader')
    def test_delete_success(self, mock_delete, client):
        mock_delete.return_value = (True, None)
        resp = client.delete('/api/pods/pod-1', headers=auth_header())
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert "deleted" in body["data"]["message"].lower()

    @patch('OrbitServer.api.pods.delete_pod_as_leader')
    def test_delete_requires_leader(self, mock_delete, client):
        mock_delete.return_value = (False, ("Only the pod leader can delete the pod", 403))
        resp = client.delete('/api/pods/pod-1', headers=auth_header(2))
        assert resp.status_code == 403

    @patch('OrbitServer.api.pods.delete_pod_as_leader')
    def test_delete_pod_not_found(self, mock_delete, client):
        mock_delete.return_value = (False, ("Pod not found", 404))
        resp = client.delete('/api/pods/bad-id', headers=auth_header())
        assert resp.status_code == 404


class TestDeletePodAsLeaderService:
    """Service-level tests: leader check + member notifications."""

    def _pod(self):
        return {
            "id": "pod-1", "name": "Study Buds", "mission_id": 5,
            "member_ids": [1, 2, 3], "max_size": 4,
        }

    @patch('OrbitServer.services.pod_service.delete_pod')
    @patch('OrbitServer.services.pod_service.create_notification')
    @patch('OrbitServer.services.pod_service.get_pod')
    def test_leader_deletes_and_notifies_others(self, mock_get, mock_notify, mock_delete, client):
        mock_get.return_value = self._pod()
        from OrbitServer.services.pod_service import delete_pod_as_leader
        ok, err = delete_pod_as_leader("pod-1", 1)
        assert ok is True
        assert err is None
        mock_delete.assert_called_once_with("pod-1")
        # Members 2 and 3 notified; leader (1) is not
        notified = [call.args[0] for call in mock_notify.call_args_list]
        assert sorted(notified) == [2, 3]
        assert all(call.args[1] == 'pod_deleted' for call in mock_notify.call_args_list)

    @patch('OrbitServer.services.pod_service.delete_pod')
    @patch('OrbitServer.services.pod_service.get_pod')
    def test_non_leader_cannot_delete(self, mock_get, mock_delete, client):
        mock_get.return_value = self._pod()
        from OrbitServer.services.pod_service import delete_pod_as_leader
        ok, err = delete_pod_as_leader("pod-1", 2)
        assert ok is False
        assert err[1] == 403
        assert "leader" in err[0].lower()
        mock_delete.assert_not_called()

    @patch('OrbitServer.services.pod_service.get_pod')
    def test_non_member_cannot_delete(self, mock_get, client):
        mock_get.return_value = self._pod()
        from OrbitServer.services.pod_service import delete_pod_as_leader
        ok, err = delete_pod_as_leader("pod-1", 99)
        assert ok is False
        assert err[1] == 403


class TestLeaderOnlyInvite:
    @patch('OrbitServer.services.pod_invite_service.get_pod')
    def test_non_leader_cannot_invite(self, mock_get, client):
        mock_get.return_value = {"id": "pod-1", "member_ids": [1, 2], "max_size": 4}
        from OrbitServer.services.pod_invite_service import send_pod_invite
        invite, err, status = send_pod_invite("pod-1", 2, 5)
        assert invite is None
        assert status == 403
        assert "leader" in err.lower()

    @patch('OrbitServer.services.pod_invite_service.create_pod_invite')
    @patch('OrbitServer.services.pod_invite_service.get_user')
    @patch('OrbitServer.services.pod_invite_service.find_pending_pod_invite')
    @patch('OrbitServer.services.pod_invite_service.find_friendship')
    @patch('OrbitServer.services.pod_invite_service.get_pod')
    def test_leader_can_invite(self, mock_get, mock_friend, mock_pending,
                               mock_user, mock_create, client):
        mock_get.return_value = {"id": "pod-1", "member_ids": [1, 2], "max_size": 4}
        mock_friend.return_value = {"id": 1}
        mock_pending.return_value = None
        mock_user.return_value = {"name": "Alex", "photo": None}
        mock_create.return_value = {"id": 7, "pod_id": "pod-1"}
        from OrbitServer.services.pod_invite_service import send_pod_invite
        invite, err, status = send_pod_invite("pod-1", 1, 5)
        assert err is None
        assert invite["id"] == 7


class TestPodLimit:
    @patch('OrbitServer.services.pod_service.at_pod_limit')
    @patch('OrbitServer.services.pod_service.get_user_pod_for_mission')
    @patch('OrbitServer.services.pod_service.get_mission')
    def test_join_blocked_at_15_pods(self, mock_mission, mock_existing, mock_limit, client):
        mock_mission.return_value = {"id": 1, "status": "open", "max_pod_size": 4}
        mock_existing.return_value = None
        mock_limit.return_value = True
        from OrbitServer.services.pod_service import join_mission
        pod, err = join_mission(1, 7)
        assert pod is None
        assert "15 pods" in err

    @patch('OrbitServer.services.pod_invite_service.get_pod_invite')
    def test_accept_invite_blocked_at_15_pods(self, mock_invite, client):
        mock_invite.return_value = {"id": 3, "to_user_id": 7, "status": "pending", "pod_id": "pod-1"}
        with patch('OrbitServer.services.pod_service.at_pod_limit', return_value=True):
            from OrbitServer.services.pod_invite_service import accept_pod_invite
            pod, err, status = accept_pod_invite(3, 7)
        assert pod is None
        assert status == 409
        assert "15 pods" in err


class TestEditPod:
    """Leader-only pod editing (name + meeting place) with chat announcements."""

    def _pod(self):
        return {
            "id": "pod-1", "name": "Old Name", "mission_id": 5,
            "member_ids": [1, 2, 3], "max_size": 4,
            "scheduled_place": "Library",
        }

    @patch('OrbitServer.models.models.create_chat_message')
    @patch('OrbitServer.services.pod_service.update_pod')
    @patch('OrbitServer.services.pod_service.get_pod')
    def test_leader_edits_name_and_place(self, mock_get, mock_update, mock_msg, client):
        mock_get.return_value = self._pod()
        mock_update.return_value = {**self._pod(), "name": "New Name", "scheduled_place": "Cafe"}
        from OrbitServer.services.pod_service import edit_pod
        pod, err, status = edit_pod("pod-1", 1, {"name": "New Name", "scheduled_place": "Cafe"})
        assert err is None
        assert pod["name"] == "New Name"
        mock_update.assert_called_once_with(
            "pod-1", {"name": "New Name", "scheduled_place": "Cafe"})
        # Both changes announced as system messages
        assert mock_msg.call_count == 2
        assert all(call.kwargs.get('message_type') == 'system'
                   or (len(call.args) > 3 and call.args[3] == 'system')
                   for call in mock_msg.call_args_list)

    @patch('OrbitServer.services.pod_service.update_pod')
    @patch('OrbitServer.services.pod_service.get_pod')
    def test_non_leader_cannot_edit(self, mock_get, mock_update, client):
        mock_get.return_value = self._pod()
        from OrbitServer.services.pod_service import edit_pod
        pod, err, status = edit_pod("pod-1", 2, {"name": "Hijacked"})
        assert pod is None
        assert status == 403
        assert "leader" in err.lower()
        mock_update.assert_not_called()

    @patch('OrbitServer.services.pod_service.update_pod')
    @patch('OrbitServer.services.pod_service.get_pod')
    def test_no_changes_is_noop(self, mock_get, mock_update, client):
        mock_get.return_value = self._pod()
        from OrbitServer.services.pod_service import edit_pod
        pod, err, status = edit_pod("pod-1", 1, {"name": "Old Name", "scheduled_place": "Library"})
        assert err is None
        mock_update.assert_not_called()

    @patch('OrbitServer.services.pod_service.get_pod')
    def test_rejects_empty_name(self, mock_get, client):
        mock_get.return_value = self._pod()
        from OrbitServer.services.pod_service import edit_pod
        pod, err, status = edit_pod("pod-1", 1, {"name": "   "})
        assert status == 400

    @patch('OrbitServer.api.pods.edit_pod')
    def test_put_route(self, mock_edit, client):
        mock_edit.return_value = ({"id": "pod-1", "name": "New"}, None, None)
        resp = client.put('/api/pods/pod-1', headers=auth_header(),
                          json={"name": "New"})
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["data"]["name"] == "New"

    @patch('OrbitServer.api.pods.edit_pod')
    def test_rename_route_now_leader_only(self, mock_edit, client):
        mock_edit.return_value = (None, "Only the pod leader can edit the pod", 403)
        resp = client.put('/api/pods/pod-1/name', headers=auth_header(2),
                          json={"name": "New"})
        assert resp.status_code == 403
