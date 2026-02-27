"""Tests for services/pod_service.py — pod assignment and attendance logic."""

from unittest.mock import patch


def _run_closure(pod_id, update_fn):
    """Helper: simulate transactional_pod_update by running the closure on a fake entity."""
    # We need to get the entity data from the test — stored on this function
    entity = dict(_run_closure._entity)
    result = update_fn(entity)
    return result, entity


class TestJoinEvent:
    @patch('OrbitServer.services.pod_service.get_event')
    def test_event_not_found(self, mock_get_event):
        from OrbitServer.services.pod_service import join_event
        mock_get_event.return_value = None

        pod, err = join_event(999, 1)
        assert pod is None
        assert "not found" in err.lower()

    @patch('OrbitServer.services.pod_service.get_event')
    def test_event_not_open(self, mock_get_event):
        from OrbitServer.services.pod_service import join_event
        mock_get_event.return_value = {'id': 1, 'status': 'completed', 'max_pod_size': 4}

        pod, err = join_event(1, 1)
        assert pod is None
        assert err is not None

    @patch('OrbitServer.services.pod_service.get_user_pod_for_event')
    @patch('OrbitServer.services.pod_service.get_event')
    def test_returns_existing_pod(self, mock_get_event, mock_existing):
        from OrbitServer.services.pod_service import join_event
        mock_get_event.return_value = {'id': 1, 'status': 'open', 'max_pod_size': 4}
        mock_existing.return_value = {'id': 'pod-abc', 'event_id': 1}

        pod, err = join_event(1, 5)
        assert err is None
        assert pod['id'] == 'pod-abc'

    @patch('OrbitServer.services.pod_service.record_event_action')
    @patch('OrbitServer.services.pod_service.transactional_pod_update')
    @patch('OrbitServer.services.pod_service.find_open_pod_for_event')
    @patch('OrbitServer.services.pod_service.get_user_pod_for_event')
    @patch('OrbitServer.services.pod_service.get_event')
    def test_joins_existing_open_pod(self, mock_event, mock_existing, mock_find,
                                     mock_trans, mock_record):
        from OrbitServer.services.pod_service import join_event
        mock_event.return_value = {'id': 1, 'status': 'open', 'max_pod_size': 4, 'tags': []}
        mock_existing.return_value = None
        mock_find.return_value = {'id': 'pod-1', 'member_ids': [2, 3], 'status': 'open'}

        def side_effect(pod_id, update_fn):
            entity = {'id': 'pod-1', 'member_ids': [2, 3], 'status': 'open', 'max_size': 4}
            result = update_fn(entity)
            return result, entity
        mock_trans.side_effect = side_effect

        pod, err = join_event(1, 5)
        assert err is None
        mock_trans.assert_called_once()
        assert 5 in pod['member_ids']

    @patch('OrbitServer.services.pod_service.record_event_action')
    @patch('OrbitServer.services.pod_service.create_event_pod')
    @patch('OrbitServer.services.pod_service.find_open_pod_for_event')
    @patch('OrbitServer.services.pod_service.get_user_pod_for_event')
    @patch('OrbitServer.services.pod_service.get_event')
    def test_creates_new_pod_when_none_open(self, mock_event, mock_existing, mock_find,
                                            mock_create, mock_record):
        from OrbitServer.services.pod_service import join_event
        mock_event.return_value = {'id': 1, 'status': 'open', 'max_pod_size': 4, 'tags': []}
        mock_existing.return_value = None
        mock_find.return_value = None
        mock_create.return_value = {'id': 'pod-new', 'member_ids': [5]}

        pod, err = join_event(1, 5)
        assert err is None
        mock_create.assert_called_once_with(1, max_size=4, first_member_id=5)

    @patch('OrbitServer.services.pod_service.record_event_action')
    @patch('OrbitServer.services.pod_service.transactional_pod_update')
    @patch('OrbitServer.services.pod_service.find_open_pod_for_event')
    @patch('OrbitServer.services.pod_service.get_user_pod_for_event')
    @patch('OrbitServer.services.pod_service.get_event')
    def test_pod_marked_full_when_at_cap(self, mock_event, mock_existing, mock_find,
                                         mock_trans, mock_record):
        from OrbitServer.services.pod_service import join_event
        mock_event.return_value = {'id': 1, 'status': 'open', 'max_pod_size': 4, 'tags': []}
        mock_existing.return_value = None
        # 3 members already, adding user 5 hits max_pod_size of 4
        mock_find.return_value = {'id': 'pod-1', 'member_ids': [2, 3, 4], 'status': 'open'}

        def side_effect(pod_id, update_fn):
            entity = {'id': 'pod-1', 'member_ids': [2, 3, 4], 'status': 'open', 'max_size': 4}
            result = update_fn(entity)
            return result, entity
        mock_trans.side_effect = side_effect

        pod, err = join_event(1, 5)
        assert err is None
        assert pod['status'] == 'full'
        assert 5 in pod['member_ids']

    @patch('OrbitServer.services.pod_service.record_event_action')
    @patch('OrbitServer.services.pod_service.find_open_pod_for_event')
    @patch('OrbitServer.services.pod_service.get_user_pod_for_event')
    @patch('OrbitServer.services.pod_service.get_event')
    def test_records_joined_action(self, mock_event, mock_existing, mock_find,
                                   mock_record):
        from OrbitServer.services.pod_service import join_event
        mock_event.return_value = {'id': 1, 'status': 'open', 'max_pod_size': 4, 'tags': []}
        mock_existing.return_value = None
        mock_find.return_value = None
        with patch('OrbitServer.services.pod_service.create_event_pod') as mock_create:
            mock_create.return_value = {'id': 'pod-new', 'member_ids': [5]}
            join_event(1, 5)
            mock_record.assert_called_once()

    @patch('OrbitServer.services.pod_service.record_event_action')
    @patch('OrbitServer.services.pod_service.create_event_pod')
    @patch('OrbitServer.services.pod_service.transactional_pod_update')
    @patch('OrbitServer.services.pod_service.find_open_pod_for_event')
    @patch('OrbitServer.services.pod_service.get_user_pod_for_event')
    @patch('OrbitServer.services.pod_service.get_event')
    def test_creates_new_pod_when_transaction_finds_full(self, mock_event, mock_existing,
                                                         mock_find, mock_trans,
                                                         mock_create, mock_record):
        """If the pod fills up between find and transaction, a new pod is created."""
        from OrbitServer.services.pod_service import join_event
        mock_event.return_value = {'id': 1, 'status': 'open', 'max_pod_size': 4, 'tags': []}
        mock_existing.return_value = None
        mock_find.return_value = {'id': 'pod-1', 'member_ids': [2, 3, 4], 'status': 'open'}

        def side_effect(pod_id, update_fn):
            # Simulate pod already full when transaction runs
            entity = {'id': 'pod-1', 'member_ids': [2, 3, 4, 99], 'status': 'full', 'max_size': 4}
            result = update_fn(entity)
            return result, entity
        mock_trans.side_effect = side_effect
        mock_create.return_value = {'id': 'pod-new', 'member_ids': [5]}

        pod, err = join_event(1, 5)
        assert err is None
        mock_create.assert_called_once()
        assert pod['id'] == 'pod-new'


class TestLeaveEvent:
    @patch('OrbitServer.services.pod_service.get_user_pod_for_event')
    def test_not_in_pod(self, mock_existing):
        from OrbitServer.services.pod_service import leave_event
        mock_existing.return_value = None

        result, err = leave_event(1, 5)
        assert result is False
        assert "not in a pod" in err.lower()

    @patch('OrbitServer.services.pod_service.transactional_pod_update')
    @patch('OrbitServer.services.pod_service.get_user_pod_for_event')
    def test_leaves_successfully(self, mock_existing, mock_trans):
        from OrbitServer.services.pod_service import leave_event
        mock_existing.return_value = {'id': 'pod-1', 'member_ids': [5, 6], 'max_size': 4, 'status': 'full'}

        def side_effect(pod_id, update_fn):
            entity = {'id': 'pod-1', 'member_ids': [5, 6], 'max_size': 4, 'status': 'full'}
            update_fn(entity)
            return None, entity
        mock_trans.side_effect = side_effect

        result, err = leave_event(1, 5)
        assert result is True
        assert err is None
        mock_trans.assert_called_once()


class TestConfirmAttendance:
    @patch('OrbitServer.services.pod_service.get_event_pod')
    def test_pod_not_found(self, mock_get):
        from OrbitServer.services.pod_service import confirm_attendance
        mock_get.return_value = None

        pod, err = confirm_attendance('bad-id', 1)
        assert pod is None
        assert "not found" in err.lower()

    @patch('OrbitServer.services.pod_service.get_event_pod')
    def test_not_a_member(self, mock_get):
        from OrbitServer.services.pod_service import confirm_attendance
        mock_get.return_value = {'id': 'pod-1', 'member_ids': [2, 3], 'confirmed_attendees': []}

        pod, err = confirm_attendance('pod-1', 99)
        assert pod is None
        assert "not a member" in err.lower()

    @patch('OrbitServer.services.pod_service.adjust_trust_score')
    @patch('OrbitServer.services.pod_service.transactional_pod_update')
    @patch('OrbitServer.services.pod_service.get_event_pod')
    def test_confirms_and_awards_points(self, mock_get, mock_trans, mock_adjust):
        from OrbitServer.services.pod_service import confirm_attendance
        mock_get.return_value = {
            'id': 'pod-1', 'member_ids': [1, 2], 'confirmed_attendees': []
        }

        def side_effect(pod_id, update_fn):
            entity = {'id': 'pod-1', 'member_ids': [1, 2], 'confirmed_attendees': []}
            update_fn(entity)
            return None, entity
        mock_trans.side_effect = side_effect

        pod, err = confirm_attendance('pod-1', 1)
        assert err is None
        mock_adjust.assert_called_once()
        assert 1 in pod['confirmed_attendees']

    @patch('OrbitServer.services.pod_service.adjust_trust_score')
    @patch('OrbitServer.services.pod_service.transactional_pod_update')
    @patch('OrbitServer.services.pod_service.get_event_pod')
    def test_does_not_double_confirm(self, mock_get, mock_trans, mock_adjust):
        from OrbitServer.services.pod_service import confirm_attendance
        # User 1 already confirmed
        mock_get.return_value = {
            'id': 'pod-1', 'member_ids': [1, 2], 'confirmed_attendees': [1]
        }

        def side_effect(pod_id, update_fn):
            entity = {'id': 'pod-1', 'member_ids': [1, 2], 'confirmed_attendees': [1]}
            update_fn(entity)
            return None, entity
        mock_trans.side_effect = side_effect

        pod, err = confirm_attendance('pod-1', 1)
        assert err is None
        assert pod['confirmed_attendees'].count(1) == 1  # not added twice

    @patch('OrbitServer.services.pod_service.adjust_trust_score')
    @patch('OrbitServer.services.pod_service.transactional_pod_update')
    @patch('OrbitServer.services.pod_service.get_event_pod')
    def test_marks_pod_completed_when_majority_confirmed(self, mock_get, mock_trans, mock_adjust):
        from OrbitServer.services.pod_service import confirm_attendance
        # 2 members, 1 confirming → 1/2 = 50%, meets the 0.5 threshold
        mock_get.return_value = {
            'id': 'pod-1', 'member_ids': [1, 2], 'confirmed_attendees': []
        }

        def side_effect(pod_id, update_fn):
            entity = {'id': 'pod-1', 'member_ids': [1, 2], 'confirmed_attendees': []}
            update_fn(entity)
            return None, entity
        mock_trans.side_effect = side_effect

        pod, err = confirm_attendance('pod-1', 1)
        assert err is None
        assert pod['status'] == 'completed'
