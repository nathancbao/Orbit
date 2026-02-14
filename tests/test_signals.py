"""Tests for Orbit Signals — cluster discovery, signal lifecycle, and API."""

import datetime
from unittest.mock import patch, MagicMock

from OrbitServer.signals.math import (
    find_signal_cluster,
    weighted_match_score,
    VIBE_CHECK_KEYS,
)
from OrbitServer.signals.service import (
    check_for_signal,
    accept_signal,
    update_contact_info,
    _is_expired,
)


# ── Helpers ──────────────────────────────────────────────────────────────────

def _make_profile(user_id, name, interests=None, personality=None, vibe_check=None):
    """Build a profile dict matching the Datastore shape."""
    profile = {
        'user_id': user_id,
        'name': name,
        'interests': interests or [],
        'personality': personality or {
            'introvert_extrovert': 0.5,
            'spontaneous_planner': 0.5,
            'active_relaxed': 0.5,
        },
    }
    if vibe_check is not None:
        profile['vibe_check'] = vibe_check
    return profile


def _make_vibe_check(values=None, mbti_type='ENFP'):
    """Build a vibe_check dict with all 8 dimensions."""
    defaults = {k: 0.5 for k in VIBE_CHECK_KEYS}
    defaults['mbti_type'] = mbti_type
    if values:
        defaults.update(values)
    return defaults


def _similar_profiles(n, base_interests=None):
    """Create n very similar profiles (high match scores)."""
    interests = base_interests or ['hiking', 'music', 'cooking']
    profiles = {}
    for i in range(1, n + 1):
        profiles[i] = _make_profile(i, f'User{i}', interests)
    return profiles


def _diverse_profiles(n):
    """Create n maximally different profiles (low match scores)."""
    all_interests = [
        ['hiking'], ['gaming'], ['cooking'], ['reading'],
        ['dancing'], ['painting'], ['surfing'], ['chess'],
    ]
    all_personalities = [
        {'introvert_extrovert': 0.0, 'spontaneous_planner': 0.0, 'active_relaxed': 0.0},
        {'introvert_extrovert': 1.0, 'spontaneous_planner': 1.0, 'active_relaxed': 1.0},
        {'introvert_extrovert': 0.0, 'spontaneous_planner': 1.0, 'active_relaxed': 0.0},
        {'introvert_extrovert': 1.0, 'spontaneous_planner': 0.0, 'active_relaxed': 1.0},
        {'introvert_extrovert': 0.2, 'spontaneous_planner': 0.8, 'active_relaxed': 0.1},
        {'introvert_extrovert': 0.9, 'spontaneous_planner': 0.1, 'active_relaxed': 0.9},
        {'introvert_extrovert': 0.1, 'spontaneous_planner': 0.9, 'active_relaxed': 0.2},
        {'introvert_extrovert': 0.8, 'spontaneous_planner': 0.2, 'active_relaxed': 0.8},
    ]
    profiles = {}
    for i in range(1, n + 1):
        idx = (i - 1) % len(all_interests)
        profiles[i] = _make_profile(
            i, f'User{i}',
            all_interests[idx],
            all_personalities[idx],
        )
    return profiles


# ═══════════════════════════════════════════════════════════════════════════
#  find_signal_cluster() — Pure Algorithm Tests
# ═══════════════════════════════════════════════════════════════════════════

class TestFindSignalCluster:
    def test_finds_high_match_cluster(self):
        """4 similar profiles → returns a cluster of 4."""
        profiles = _similar_profiles(5)
        cluster = find_signal_cluster(1, profiles)
        assert len(cluster) == 4
        assert 1 in cluster

    def test_returns_empty_when_no_good_matches(self):
        """All profiles too different → empty list."""
        profiles = _diverse_profiles(5)
        cluster = find_signal_cluster(1, profiles, min_score=0.95)
        assert cluster == []

    def test_excludes_requesting_user_from_candidates(self):
        """Requester should not appear twice in the scoring loop."""
        profiles = _similar_profiles(4)
        cluster = find_signal_cluster(1, profiles)
        # Requester appears exactly once
        assert cluster.count(1) == 1

    def test_respects_min_score_threshold(self):
        """With a very high threshold no cluster should form."""
        profiles = _similar_profiles(5)
        # Tweak one profile to be slightly different
        profiles[2] = _make_profile(2, 'User2', ['chess', 'gaming'], {
            'introvert_extrovert': 0.1,
            'spontaneous_planner': 0.9,
            'active_relaxed': 0.1,
        })
        cluster = find_signal_cluster(1, profiles, min_score=0.99)
        # At 0.99 threshold, unlikely to get a cluster
        # (either empty or only perfect matches)
        if cluster:
            # If a cluster formed, all members should be very close
            for uid in cluster:
                if uid != 1:
                    score = weighted_match_score(profiles[1], profiles[uid])
                    assert score >= 0.99

    def test_cluster_size_between_3_and_4(self):
        """Cluster should have 3–4 members (default cluster_size=4)."""
        profiles = _similar_profiles(6)
        cluster = find_signal_cluster(1, profiles)
        assert 3 <= len(cluster) <= 4

    def test_empty_profiles_returns_empty(self):
        """No profiles at all → empty list."""
        cluster = find_signal_cluster(1, {})
        assert cluster == []

    def test_user_not_in_profiles_returns_empty(self):
        """Requester ID not in profiles dict → empty list."""
        profiles = _similar_profiles(4)
        cluster = find_signal_cluster(99, profiles)
        assert cluster == []

    def test_too_few_candidates_returns_empty(self):
        """Only 2 total profiles (requester + 1) → need at least 3."""
        profiles = _similar_profiles(2)
        cluster = find_signal_cluster(1, profiles)
        assert cluster == []

    def test_custom_cluster_size(self):
        """cluster_size=3 should return exactly 3 members."""
        profiles = _similar_profiles(5)
        cluster = find_signal_cluster(1, profiles, cluster_size=3)
        assert len(cluster) == 3

    def test_requester_always_first(self):
        """Requester should be the first element in the cluster."""
        profiles = _similar_profiles(5)
        cluster = find_signal_cluster(1, profiles)
        assert cluster[0] == 1


# ═══════════════════════════════════════════════════════════════════════════
#  _is_expired() — Expiration Helper
# ═══════════════════════════════════════════════════════════════════════════

class TestIsExpired:
    def test_none_entity_is_expired(self):
        assert _is_expired(None) is True

    def test_future_expiry_not_expired(self):
        entity = {
            'expires_at': datetime.datetime.utcnow() + datetime.timedelta(days=3),
        }
        assert _is_expired(entity) is False

    def test_past_expiry_is_expired(self):
        entity = {
            'expires_at': datetime.datetime.utcnow() - datetime.timedelta(hours=1),
        }
        assert _is_expired(entity) is True

    def test_no_expires_at_not_expired(self):
        entity = {'status': 'pending'}
        assert _is_expired(entity) is False

    def test_string_expires_at(self):
        future = (datetime.datetime.utcnow() + datetime.timedelta(days=1)).isoformat()
        entity = {'expires_at': future}
        assert _is_expired(entity) is False


# ═══════════════════════════════════════════════════════════════════════════
#  check_for_signal() — Service Layer
# ═══════════════════════════════════════════════════════════════════════════

class TestCheckForSignal:
    @patch('OrbitServer.signals.service._get_available_profiles', return_value={})
    @patch('OrbitServer.signals.service.get_signal_for_user', return_value=None)
    @patch('OrbitServer.signals.service._db_get_active_pod', return_value=None)
    @patch('OrbitServer.signals.service.get_profile')
    def test_returns_no_match_when_no_compatible_users(
        self, mock_profile, mock_pod, mock_signal, mock_avail,
    ):
        mock_profile.return_value = {'name': 'Ada', 'interests': []}
        data, err = check_for_signal(1)
        assert err is None
        assert data['status'] == 'no_match'

    @patch('OrbitServer.signals.service.get_profile', return_value=None)
    def test_requires_complete_profile(self, mock_profile):
        data, err = check_for_signal(1)
        assert data is None
        assert 'profile' in err.lower()

    @patch('OrbitServer.signals.service.get_profile', return_value={'name': '', 'interests': []})
    def test_requires_name_in_profile(self, mock_profile):
        data, err = check_for_signal(1)
        assert data is None
        assert 'profile' in err.lower()

    @patch('OrbitServer.signals.service.get_profile')
    @patch('OrbitServer.signals.service._db_get_active_pod')
    def test_returns_active_pod_if_exists(self, mock_pod, mock_profile):
        mock_profile.side_effect = lambda uid: {'name': f'User{uid}', 'interests': []}
        future = datetime.datetime.utcnow() + datetime.timedelta(days=5)
        mock_pod.return_value = {
            'id': 'pod-1',
            'members': [1, 2, 3],
            'expires_at': future,
            'revealed': False,
        }
        data, err = check_for_signal(1)
        assert err is None
        assert data['status'] == 'has_pod'
        assert data['pod']['id'] == 'pod-1'
        assert len(data['members']) == 3
        assert data['revealed'] is False

    @patch('OrbitServer.signals.service.get_profile')
    @patch('OrbitServer.signals.service.get_signal_for_user')
    @patch('OrbitServer.signals.service._db_get_active_pod', return_value=None)
    def test_returns_pending_signal_if_exists(self, mock_pod, mock_signal, mock_profile):
        mock_profile.side_effect = lambda uid: {'name': f'User{uid}', 'interests': []}
        future = datetime.datetime.utcnow() + datetime.timedelta(days=5)
        mock_signal.return_value = {
            'id': 'sig-1',
            'target_user_ids': [1, 2, 3],
            'accepted_user_ids': [1],
            'status': 'pending',
            'expires_at': future,
        }
        data, err = check_for_signal(1)
        assert err is None
        assert data['status'] == 'has_signal'
        assert data['signal']['id'] == 'sig-1'

    @patch('OrbitServer.signals.service._get_available_profiles')
    @patch('OrbitServer.signals.service._db_create_signal')
    @patch('OrbitServer.signals.service.get_profile')
    @patch('OrbitServer.signals.service.get_signal_for_user', return_value=None)
    @patch('OrbitServer.signals.service._db_get_active_pod', return_value=None)
    def test_creates_new_signal_when_matches_found(
        self, mock_pod, mock_signal, mock_profile, mock_create, mock_avail,
    ):
        profiles = _similar_profiles(5)
        mock_profile.side_effect = lambda uid: profiles.get(uid, {'name': f'User{uid}', 'interests': []})
        mock_avail.return_value = profiles
        mock_create.return_value = {
            'id': 'new-sig',
            'target_user_ids': [1, 2, 3, 4],
            'accepted_user_ids': [],
            'status': 'pending',
        }

        data, err = check_for_signal(1)
        assert err is None
        assert data['status'] == 'new_signal'
        assert data['signal']['id'] == 'new-sig'
        mock_create.assert_called_once()

    @patch('OrbitServer.signals.service.get_profile')
    @patch('OrbitServer.signals.service.get_signal_for_user')
    @patch('OrbitServer.signals.service._db_get_active_pod')
    def test_skips_expired_pods(self, mock_pod, mock_signal, mock_profile):
        mock_profile.side_effect = lambda uid: {'name': f'User{uid}', 'interests': []}
        past = datetime.datetime.utcnow() - datetime.timedelta(days=1)
        mock_pod.return_value = {
            'id': 'pod-old',
            'members': [1, 2, 3],
            'expires_at': past,
            'revealed': False,
        }
        mock_signal.return_value = None

        with patch('OrbitServer.signals.service._get_available_profiles', return_value={}):
            data, err = check_for_signal(1)
        assert err is None
        # Should not return the expired pod — should fall through
        assert data['status'] == 'no_match'

    @patch('OrbitServer.signals.service._get_available_profiles', return_value={})
    @patch('OrbitServer.signals.service.get_profile')
    @patch('OrbitServer.signals.service.get_signal_for_user')
    @patch('OrbitServer.signals.service._db_get_active_pod', return_value=None)
    def test_skips_expired_signals(self, mock_pod, mock_signal, mock_profile, mock_avail):
        mock_profile.side_effect = lambda uid: {'name': f'User{uid}', 'interests': []}
        past = datetime.datetime.utcnow() - datetime.timedelta(days=1)
        mock_signal.return_value = {
            'id': 'sig-old',
            'target_user_ids': [1, 2, 3],
            'accepted_user_ids': [],
            'status': 'pending',
            'expires_at': past,
        }
        data, err = check_for_signal(1)
        assert err is None
        assert data['status'] == 'no_match'


# ═══════════════════════════════════════════════════════════════════════════
#  accept_signal() — Service Layer
# ═══════════════════════════════════════════════════════════════════════════

class TestAcceptSignal:
    @patch('OrbitServer.signals.service._db_accept_signal')
    @patch('OrbitServer.signals.service._db_get_signal')
    @patch('OrbitServer.signals.service.get_profile')
    def test_accept_records_user(self, mock_profile, mock_get, mock_accept):
        mock_profile.side_effect = lambda uid: {'name': f'User{uid}', 'interests': []}
        future = datetime.datetime.utcnow() + datetime.timedelta(days=5)
        mock_get.return_value = {
            'id': 'sig-1',
            'target_user_ids': [1, 2, 3],
            'accepted_user_ids': [],
            'status': 'pending',
            'expires_at': future,
        }
        mock_accept.return_value = {
            'id': 'sig-1',
            'target_user_ids': [1, 2, 3],
            'accepted_user_ids': [1],
            'status': 'pending',
            'expires_at': future,
        }

        data, err = accept_signal(1, 'sig-1')
        assert err is None
        assert data['status'] == 'has_signal'
        mock_accept.assert_called_once_with('sig-1', 1)

    @patch('OrbitServer.signals.service._db_get_signal', return_value=None)
    def test_reject_if_signal_not_found(self, mock_get):
        data, err = accept_signal(1, 'nonexistent')
        assert data is None
        assert 'not found' in err.lower()

    @patch('OrbitServer.signals.service._db_get_signal')
    def test_reject_if_not_target_user(self, mock_get):
        future = datetime.datetime.utcnow() + datetime.timedelta(days=5)
        mock_get.return_value = {
            'id': 'sig-1',
            'target_user_ids': [2, 3, 4],
            'accepted_user_ids': [],
            'status': 'pending',
            'expires_at': future,
        }
        data, err = accept_signal(99, 'sig-1')
        assert data is None
        assert 'not part' in err.lower()

    @patch('OrbitServer.signals.service._db_get_signal')
    def test_reject_if_signal_expired(self, mock_get):
        past = datetime.datetime.utcnow() - datetime.timedelta(hours=1)
        mock_get.return_value = {
            'id': 'sig-1',
            'target_user_ids': [1, 2, 3],
            'accepted_user_ids': [],
            'status': 'pending',
            'expires_at': past,
        }
        data, err = accept_signal(1, 'sig-1')
        assert data is None
        assert 'expired' in err.lower()

    @patch('OrbitServer.signals.service.create_pod_from_signal')
    @patch('OrbitServer.signals.service._db_accept_signal')
    @patch('OrbitServer.signals.service._db_get_signal')
    @patch('OrbitServer.signals.service.get_profile')
    def test_all_accepted_creates_pod(self, mock_profile, mock_get, mock_accept, mock_create_pod):
        mock_profile.side_effect = lambda uid: {'name': f'User{uid}', 'interests': []}
        future = datetime.datetime.utcnow() + datetime.timedelta(days=5)
        mock_get.return_value = {
            'id': 'sig-1',
            'target_user_ids': [1, 2, 3],
            'accepted_user_ids': [2, 3],
            'status': 'pending',
            'expires_at': future,
        }
        # After user 1 accepts, all 3 are in
        mock_accept.return_value = {
            'id': 'sig-1',
            'target_user_ids': [1, 2, 3],
            'accepted_user_ids': [1, 2, 3],
            'status': 'accepted',
            'expires_at': future,
        }
        pod_future = datetime.datetime.utcnow() + datetime.timedelta(days=7)
        mock_create_pod.return_value = {
            'id': 'pod-new',
            'members': [1, 2, 3],
            'created_at': datetime.datetime.utcnow(),
            'expires_at': pod_future,
            'revealed': False,
            'signal_id': 'sig-1',
        }

        data, err = accept_signal(1, 'sig-1')
        assert err is None
        assert data['status'] == 'has_pod'
        assert data['pod']['id'] == 'pod-new'
        mock_create_pod.assert_called_once()

    @patch('OrbitServer.signals.service._db_accept_signal')
    @patch('OrbitServer.signals.service._db_get_signal')
    @patch('OrbitServer.signals.service.get_profile')
    def test_partial_acceptance_stays_pending(self, mock_profile, mock_get, mock_accept):
        mock_profile.side_effect = lambda uid: {'name': f'User{uid}', 'interests': []}
        future = datetime.datetime.utcnow() + datetime.timedelta(days=5)
        mock_get.return_value = {
            'id': 'sig-1',
            'target_user_ids': [1, 2, 3, 4],
            'accepted_user_ids': [],
            'status': 'pending',
            'expires_at': future,
        }
        mock_accept.return_value = {
            'id': 'sig-1',
            'target_user_ids': [1, 2, 3, 4],
            'accepted_user_ids': [1],
            'status': 'pending',
            'expires_at': future,
        }

        data, err = accept_signal(1, 'sig-1')
        assert err is None
        assert data['status'] == 'has_signal'

    @patch('OrbitServer.signals.service.create_pod_from_signal')
    @patch('OrbitServer.signals.service._db_accept_signal')
    @patch('OrbitServer.signals.service._db_get_signal')
    @patch('OrbitServer.signals.service.get_profile')
    def test_pod_has_7_day_expiry(self, mock_profile, mock_get, mock_accept, mock_create_pod):
        mock_profile.side_effect = lambda uid: {'name': f'User{uid}', 'interests': []}
        future = datetime.datetime.utcnow() + datetime.timedelta(days=5)
        mock_get.return_value = {
            'id': 'sig-1',
            'target_user_ids': [1, 2],
            'accepted_user_ids': [2],
            'status': 'pending',
            'expires_at': future,
        }
        mock_accept.return_value = {
            'id': 'sig-1',
            'target_user_ids': [1, 2],
            'accepted_user_ids': [1, 2],
            'status': 'accepted',
            'expires_at': future,
        }
        now = datetime.datetime.utcnow()
        pod_expires = now + datetime.timedelta(days=7)
        mock_create_pod.return_value = {
            'id': 'pod-1',
            'members': [1, 2],
            'created_at': now,
            'expires_at': pod_expires,
            'revealed': False,
            'signal_id': 'sig-1',
        }

        data, err = accept_signal(1, 'sig-1')
        assert err is None
        pod = data['pod']
        # Pod should expire ~7 days from now
        expires = pod['expires_at']
        diff = expires - now
        assert 6 <= diff.days <= 7

    @patch('OrbitServer.signals.service.create_pod_from_signal')
    @patch('OrbitServer.signals.service._db_accept_signal')
    @patch('OrbitServer.signals.service._db_get_signal')
    @patch('OrbitServer.signals.service.get_profile')
    def test_pod_starts_unrevealed(self, mock_profile, mock_get, mock_accept, mock_create_pod):
        mock_profile.side_effect = lambda uid: {'name': f'User{uid}', 'interests': []}
        future = datetime.datetime.utcnow() + datetime.timedelta(days=5)
        mock_get.return_value = {
            'id': 'sig-1',
            'target_user_ids': [1, 2],
            'accepted_user_ids': [2],
            'status': 'pending',
            'expires_at': future,
        }
        mock_accept.return_value = {
            'id': 'sig-1',
            'target_user_ids': [1, 2],
            'accepted_user_ids': [1, 2],
            'status': 'accepted',
            'expires_at': future,
        }
        mock_create_pod.return_value = {
            'id': 'pod-1',
            'members': [1, 2],
            'created_at': datetime.datetime.utcnow(),
            'expires_at': datetime.datetime.utcnow() + datetime.timedelta(days=7),
            'revealed': False,
            'signal_id': 'sig-1',
        }

        data, err = accept_signal(1, 'sig-1')
        assert err is None
        assert data['revealed'] is False

    @patch('OrbitServer.signals.service._db_get_signal')
    def test_reject_if_already_accepted(self, mock_get):
        future = datetime.datetime.utcnow() + datetime.timedelta(days=5)
        mock_get.return_value = {
            'id': 'sig-1',
            'target_user_ids': [1, 2, 3],
            'accepted_user_ids': [1, 2, 3],
            'status': 'accepted',
            'expires_at': future,
        }
        data, err = accept_signal(1, 'sig-1')
        assert data is None
        assert 'already' in err.lower()


# ═══════════════════════════════════════════════════════════════════════════
#  update_contact_info() — Service Layer
# ═══════════════════════════════════════════════════════════════════════════

class TestUpdateContactInfo:
    @patch('OrbitServer.signals.service._db_upsert_contact_info')
    def test_upsert_creates_new(self, mock_upsert):
        mock_upsert.return_value = {
            'id': 1,
            'instagram': '@ada',
            'phone': '555-1234',
        }
        data, err = update_contact_info(1, {'instagram': '@ada', 'phone': '555-1234'})
        assert err is None
        assert data['instagram'] == '@ada'

    @patch('OrbitServer.signals.service._db_upsert_contact_info')
    def test_upsert_updates_existing(self, mock_upsert):
        mock_upsert.return_value = {
            'id': 1,
            'instagram': '@ada_new',
            'phone': '555-9999',
        }
        data, err = update_contact_info(1, {'instagram': '@ada_new', 'phone': '555-9999'})
        assert err is None
        assert data['instagram'] == '@ada_new'

    def test_rejects_empty_body(self):
        data, err = update_contact_info(1, {})
        assert data is None
        assert 'provide' in err.lower()

    def test_rejects_none_body(self):
        data, err = update_contact_info(1, None)
        assert data is None
        assert err is not None

    @patch('OrbitServer.signals.service._db_upsert_contact_info')
    def test_accepts_instagram_only(self, mock_upsert):
        mock_upsert.return_value = {'id': 1, 'instagram': '@ada'}
        data, err = update_contact_info(1, {'instagram': '@ada'})
        assert err is None

    @patch('OrbitServer.signals.service._db_upsert_contact_info')
    def test_accepts_phone_only(self, mock_upsert):
        mock_upsert.return_value = {'id': 1, 'phone': '555-0000'}
        data, err = update_contact_info(1, {'phone': '555-0000'})
        assert err is None


# ═══════════════════════════════════════════════════════════════════════════
#  Signal & Pod Expiration
# ═══════════════════════════════════════════════════════════════════════════

class TestSignalExpiration:
    def test_signal_expires_after_7_days(self):
        now = datetime.datetime.utcnow()
        signal = {
            'expires_at': now + datetime.timedelta(days=7),
            'status': 'pending',
        }
        assert _is_expired(signal) is False

        old_signal = {
            'expires_at': now - datetime.timedelta(days=1),
            'status': 'pending',
        }
        assert _is_expired(old_signal) is True

    def test_pod_expires_after_7_days(self):
        now = datetime.datetime.utcnow()
        pod = {
            'expires_at': now + datetime.timedelta(days=7),
            'revealed': False,
        }
        assert _is_expired(pod) is False

        old_pod = {
            'expires_at': now - datetime.timedelta(hours=1),
            'revealed': True,
        }
        assert _is_expired(old_pod) is True


# ═══════════════════════════════════════════════════════════════════════════
#  API Routes
# ═══════════════════════════════════════════════════════════════════════════

class TestSignalsAPI:
    @patch('OrbitServer.signals.service._get_available_profiles', return_value={})
    @patch('OrbitServer.signals.service.get_signal_for_user', return_value=None)
    @patch('OrbitServer.signals.service._db_get_active_pod', return_value=None)
    @patch('OrbitServer.signals.service.get_profile', return_value={'name': 'Ada', 'interests': []})
    @patch('OrbitServer.utils.auth.decode_token', return_value=({'user_id': 42, 'type': 'access'}, None))
    def test_get_signal_endpoint(self, mock_decode, mock_profile, mock_pod, mock_signal, mock_avail, client):
        resp = client.get('/api/signals/signal', headers={'Authorization': 'Bearer fake'})
        assert resp.status_code == 200
        json_data = resp.get_json()
        assert json_data['success'] is True
        assert json_data['data']['status'] == 'no_match'

    @patch('OrbitServer.signals.service._db_accept_signal')
    @patch('OrbitServer.signals.service._db_get_signal')
    @patch('OrbitServer.signals.service.get_profile')
    @patch('OrbitServer.utils.auth.decode_token', return_value=({'user_id': 42, 'type': 'access'}, None))
    def test_accept_endpoint(self, mock_decode, mock_profile, mock_get, mock_accept, client):
        mock_profile.side_effect = lambda uid: {'name': f'User{uid}', 'interests': []}
        future = datetime.datetime.utcnow() + datetime.timedelta(days=5)
        mock_get.return_value = {
            'id': 'sig-1',
            'target_user_ids': [42, 2, 3],
            'accepted_user_ids': [],
            'status': 'pending',
            'expires_at': future,
        }
        mock_accept.return_value = {
            'id': 'sig-1',
            'target_user_ids': [42, 2, 3],
            'accepted_user_ids': [42],
            'status': 'pending',
            'expires_at': future,
        }

        resp = client.post(
            '/api/signals/signal/sig-1/accept',
            headers={'Authorization': 'Bearer fake'},
        )
        assert resp.status_code == 200
        json_data = resp.get_json()
        assert json_data['success'] is True

    @patch('OrbitServer.signals.service._db_upsert_contact_info')
    @patch('OrbitServer.utils.auth.decode_token', return_value=({'user_id': 42, 'type': 'access'}, None))
    def test_contact_info_endpoint(self, mock_decode, mock_upsert, client):
        mock_upsert.return_value = {'id': 42, 'instagram': '@ada'}
        resp = client.post(
            '/api/signals/contact-info',
            json={'instagram': '@ada'},
            headers={'Authorization': 'Bearer fake'},
        )
        assert resp.status_code == 200
        json_data = resp.get_json()
        assert json_data['success'] is True

    def test_signal_requires_auth(self, client):
        resp = client.get('/api/signals/signal')
        assert resp.status_code == 401

    def test_accept_requires_auth(self, client):
        resp = client.post('/api/signals/signal/fake-id/accept')
        assert resp.status_code == 401

    def test_contact_info_requires_auth(self, client):
        resp = client.post('/api/signals/contact-info')
        assert resp.status_code == 401
