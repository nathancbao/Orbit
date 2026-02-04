"""Tests for services/crew_service.py — crew join/leave business logic."""

from unittest.mock import patch, MagicMock


class TestJoinCrew:
    @patch('OrbitServer.services.crew_service.get_crew')
    def test_crew_not_found(self, mock_get):
        from OrbitServer.services.crew_service import join_crew
        mock_get.return_value = None

        result, err = join_crew(999, 1)
        assert result is None
        assert "not found" in err.lower()

    @patch('OrbitServer.services.crew_service.get_crew_member')
    @patch('OrbitServer.services.crew_service.get_crew')
    def test_already_a_member(self, mock_get_crew, mock_get_member):
        from OrbitServer.services.crew_service import join_crew
        mock_get_crew.return_value = {'id': 1, 'name': 'Test'}
        mock_get_member.return_value = {'crew_id': 1, 'user_id': 5}

        result, err = join_crew(1, 5)
        assert result is None
        assert "Already" in err

    @patch('OrbitServer.services.crew_service.update_crew_member_count')
    @patch('OrbitServer.services.crew_service.add_crew_member')
    @patch('OrbitServer.services.crew_service.get_crew_member')
    @patch('OrbitServer.services.crew_service.get_crew')
    def test_successful_join(self, mock_get_crew, mock_get_member,
                              mock_add, mock_update_count):
        from OrbitServer.services.crew_service import join_crew
        mock_get_crew.return_value = {'id': 1, 'name': 'Test'}
        mock_get_member.return_value = None  # not yet a member

        result, err = join_crew(1, 5)
        assert err is None
        assert "Joined" in result["message"]
        mock_add.assert_called_once_with(1, 5)
        mock_update_count.assert_called_once_with(1, 1)


class TestLeaveCrew:
    @patch('OrbitServer.services.crew_service.get_crew')
    def test_crew_not_found(self, mock_get):
        from OrbitServer.services.crew_service import leave_crew
        mock_get.return_value = None

        result, err = leave_crew(999, 1)
        assert result is None
        assert "not found" in err.lower()

    @patch('OrbitServer.services.crew_service.get_crew_member')
    @patch('OrbitServer.services.crew_service.get_crew')
    def test_not_a_member(self, mock_get_crew, mock_get_member):
        from OrbitServer.services.crew_service import leave_crew
        mock_get_crew.return_value = {'id': 1, 'name': 'Test'}
        mock_get_member.return_value = None

        result, err = leave_crew(1, 5)
        assert result is None
        assert "Not a member" in err

    @patch('OrbitServer.services.crew_service.update_crew_member_count')
    @patch('OrbitServer.services.crew_service.remove_crew_member')
    @patch('OrbitServer.services.crew_service.get_crew_member')
    @patch('OrbitServer.services.crew_service.get_crew')
    def test_successful_leave(self, mock_get_crew, mock_get_member,
                               mock_remove, mock_update_count):
        from OrbitServer.services.crew_service import leave_crew
        mock_get_crew.return_value = {'id': 1, 'name': 'Test'}
        mock_get_member.return_value = {'crew_id': 1, 'user_id': 5}

        result, err = leave_crew(1, 5)
        assert err is None
        assert "Left" in result["message"]
        mock_remove.assert_called_once_with(1, 5)
        mock_update_count.assert_called_once_with(1, -1)
