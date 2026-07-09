"""Tests for the mission 24h grace period expiry policy."""

import datetime
from unittest.mock import patch

from OrbitServer.services.mission_service import (
    check_mission_expiration, _MISSION_GRACE_PERIOD,
)


def _mission(end_offset_hours):
    """Build a set mission whose end time is `end_offset_hours` from now (UTC)."""
    end = datetime.datetime.utcnow() + datetime.timedelta(hours=end_offset_hours)
    return {
        'id': '123',
        'mode': 'set',
        'status': 'open',
        'date': end.strftime('%Y-%m-%d'),
        'start_time': (end - datetime.timedelta(hours=1)).strftime('%H:%M'),
        'end_time': end.strftime('%H:%M'),
        'utc_offset': 0,
    }


class TestMissionGracePeriod:
    def test_grace_period_is_24_hours(self):
        assert _MISSION_GRACE_PERIOD == datetime.timedelta(hours=24)

    def test_future_mission_active(self):
        assert check_mission_expiration(_mission(2)) == 'active'

    @patch('OrbitServer.services.mission_service.update_mission')
    def test_ended_mission_completed_within_grace(self, mock_update):
        # Ended 3 hours ago — old code would have deleted it; now it's 'completed'
        assert check_mission_expiration(_mission(-3)) == 'completed'

    @patch('OrbitServer.services.mission_service.delete_mission')
    def test_ended_over_24h_ago_deleted(self, mock_delete):
        assert check_mission_expiration(_mission(-26)) == 'deleted'
        mock_delete.assert_called_once()

    def test_flex_mission_always_active(self):
        assert check_mission_expiration({'mode': 'flex'}) == 'active'
