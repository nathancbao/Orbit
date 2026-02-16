"""Tests for services/mission_service.py — RSVP business logic."""

from unittest.mock import patch


class TestRsvpMission:
    @patch('OrbitServer.services.mission_service.get_mission')
    def test_mission_not_found(self, mock_get):
        from OrbitServer.services.mission_service import rsvp_mission
        mock_get.return_value = None

        result, err = rsvp_mission(999, 1)
        assert result is None
        assert "not found" in err.lower()

    @patch('OrbitServer.services.mission_service.get_mission_rsvp')
    @patch('OrbitServer.services.mission_service.get_mission')
    def test_already_rsvped(self, mock_get_mission, mock_get_rsvp):
        from OrbitServer.services.mission_service import rsvp_mission
        mock_get_mission.return_value = {'id': 1, 'title': 'Hike'}
        mock_get_rsvp.return_value = {'mission_id': 1, 'user_id': 5}

        result, err = rsvp_mission(1, 5)
        assert result is None
        assert "Already" in err

    @patch('OrbitServer.services.mission_service.update_mission_rsvp_count')
    @patch('OrbitServer.services.mission_service.add_mission_rsvp')
    @patch('OrbitServer.services.mission_service.get_mission_rsvp')
    @patch('OrbitServer.services.mission_service.get_mission')
    def test_successful_rsvp(self, mock_get_mission, mock_get_rsvp,
                              mock_add, mock_update_count):
        from OrbitServer.services.mission_service import rsvp_mission
        mock_get_mission.return_value = {'id': 1, 'title': 'Hike'}
        mock_get_rsvp.return_value = None

        result, err = rsvp_mission(1, 5)
        assert err is None
        assert "RSVP" in result["message"]
        mock_add.assert_called_once_with(1, 5, 'hard')
        mock_update_count.assert_called_once_with(1, 'hard', 1)
