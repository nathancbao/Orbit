"""Tests for the N+1 batching (get_users_batch) and last-message optimization
introduced in the reliability/efficiency pass."""

from unittest.mock import patch


class TestFriendsBatched:
    @patch('OrbitServer.services.friend_service.get_users_batch')
    @patch('OrbitServer.services.friend_service.list_friendships')
    def test_get_friends_uses_batch(self, mock_list, mock_batch):
        from OrbitServer.services.friend_service import get_friends
        mock_list.return_value = [
            {'id': 10, 'user_id': 1, 'friend_id': 2},
            {'id': 11, 'user_id': 1, 'friend_id': 3},
        ]
        mock_batch.return_value = {
            '2': {'id': 2, 'name': 'Bea', 'interests': []},
            '3': {'id': 3, 'name': 'Cal', 'interests': []},
        }

        result, err = get_friends(1)
        assert err is None
        # A single batched lookup, not one get_user per friendship.
        mock_batch.assert_called_once_with([2, 3])
        names = {f['friend']['name'] for f in result}
        assert names == {'Bea', 'Cal'}

    @patch('OrbitServer.services.friend_service.get_users_batch')
    @patch('OrbitServer.services.friend_service.list_incoming_friend_requests')
    def test_incoming_requests_missing_user_is_none(self, mock_list, mock_batch):
        from OrbitServer.services.friend_service import get_incoming_requests
        mock_list.return_value = [{'id': 5, 'from_user_id': 9}]
        mock_batch.return_value = {}  # user no longer exists

        result, err = get_incoming_requests(1)
        assert err is None
        assert result[0]['from_user'] is None


class TestPodConversationsLastMessage:
    @patch('OrbitServer.services.chat_service.get_last_chat_message')
    @patch('OrbitServer.services.chat_service.get_user_pods')
    def test_uses_last_message_helper(self, mock_pods, mock_last):
        from OrbitServer.services.chat_service import get_pod_conversations
        mock_pods.return_value = [{'id': 'pod1', 'name': 'Study', 'mission_title': 'X'}]
        mock_last.return_value = {
            'content': 'see you there',
            'created_at': '2026-07-06T12:00:00Z',
            'user_id': 5,
        }

        result, err = get_pod_conversations(1)
        assert err is None
        # The full-history load is gone; we fetch just the last message per pod.
        mock_last.assert_called_once_with('pod1')
        assert result[0]['last_message'] == 'see you there'
        assert result[0]['last_message_user_id'] == 5

    @patch('OrbitServer.services.chat_service.get_last_chat_message')
    @patch('OrbitServer.services.chat_service.get_user_pods')
    def test_empty_conversation(self, mock_pods, mock_last):
        from OrbitServer.services.chat_service import get_pod_conversations
        mock_pods.return_value = [{'id': 'pod1', 'name': 'Study'}]
        mock_last.return_value = None

        result, err = get_pod_conversations(1)
        assert err is None
        assert result[0]['last_message'] == ''
        assert result[0]['last_message_user_id'] is None
