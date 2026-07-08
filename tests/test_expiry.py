"""Tests for mission 24h grace period and signal expiry policy."""

import datetime
from unittest.mock import patch

from OrbitServer.services.mission_service import (
    check_mission_expiration, _MISSION_GRACE_PERIOD,
)
from OrbitServer.services.signal_service import (
    signal_expiry_datetime, check_signal_expiration,
    _SIGNAL_GRACE_PERIOD, _SIGNAL_FALLBACK_TTL,
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


class TestSignalExpiry:
    def test_expiry_from_latest_availability_date(self):
        signal = {
            'id': 's1',
            'availability': [
                {'date': '2026-07-01', 'hours': [9]},
                {'date': '2026-07-03', 'hours': [10]},
            ],
        }
        expiry = signal_expiry_datetime(signal)
        expected = datetime.datetime(2026, 7, 3, 23, 59) + _SIGNAL_GRACE_PERIOD
        assert expiry == expected

    def test_full_iso_date_string_parses(self):
        signal = {'id': 's2', 'availability': [{'date': '2026-07-03T00:00:00Z', 'hours': [9]}]}
        expiry = signal_expiry_datetime(signal)
        assert expiry == datetime.datetime(2026, 7, 3, 23, 59) + _SIGNAL_GRACE_PERIOD

    def test_fallback_to_created_at_plus_14_days(self):
        signal = {
            'id': 's3',
            'availability': [],
            'created_at': '2026-06-01T12:00:00Z',
        }
        expiry = signal_expiry_datetime(signal)
        assert expiry == datetime.datetime(2026, 6, 1, 12, 0) + _SIGNAL_FALLBACK_TTL

    def test_malformed_dates_fall_back(self):
        signal = {
            'id': 's4',
            'availability': [{'date': 'not-a-date'}, 'garbage', {}],
            'created_at': '2026-06-01T00:00:00Z',
        }
        expiry = signal_expiry_datetime(signal)
        assert expiry == datetime.datetime(2026, 6, 1) + _SIGNAL_FALLBACK_TTL

    def test_no_dates_at_all_never_expires(self):
        assert signal_expiry_datetime({'id': 's5', 'availability': []}) is None
        assert check_signal_expiration({'id': 's5', 'availability': []}) == 'active'

    @patch('OrbitServer.services.signal_service.delete_signal')
    def test_expired_signal_deleted(self, mock_delete):
        signal = {'id': 's6', 'availability': [{'date': '2020-01-01', 'hours': [9]}]}
        assert check_signal_expiration(signal) == 'deleted'
        mock_delete.assert_called_once_with('s6')

    @patch('OrbitServer.services.signal_service.delete_signal')
    def test_active_signal_kept(self, mock_delete):
        future = (datetime.datetime.utcnow() + datetime.timedelta(days=3)).strftime('%Y-%m-%d')
        signal = {'id': 's7', 'availability': [{'date': future, 'hours': [9]}]}
        assert check_signal_expiration(signal) == 'active'
        mock_delete.assert_not_called()
