"""
Signals — Service Layer

Orchestrates the signal lifecycle:
  1. check_for_signal  — main entry when user opens Discovery
  2. accept_signal     — user accepts a signal invite
  3. update_contact_info — user updates revealable contact info
"""

import datetime

from OrbitServer.models.models import get_profile
from OrbitServer.signals.models import (
    create_signal as _db_create_signal,
    get_signal as _db_get_signal,
    get_signal_for_user,
    accept_signal as _db_accept_signal,
    create_pod_from_signal,
    get_active_pod as _db_get_active_pod,
    upsert_contact_info as _db_upsert_contact_info,
    get_contact_info,
)
from OrbitServer.signals.math import find_signal_cluster


SIGNAL_TTL_DAYS = 7
POD_TTL_DAYS = 7


def _is_expired(entity):
    """Check if a signal/pod has passed its expires_at."""
    if not entity:
        return True
    expires_at = entity.get('expires_at')
    if expires_at is None:
        return False
    if isinstance(expires_at, str):
        expires_at = datetime.datetime.fromisoformat(expires_at)
    return datetime.datetime.utcnow() > expires_at


def _get_member_profiles(user_ids, include_contact=False):
    """Load member preview data for a list of user IDs.

    Returns a list of dicts with user_id, name, interests, and
    optionally contact_info.
    """
    members = []
    for uid in user_ids:
        profile = get_profile(uid)
        member = {
            'user_id': uid,
            'name': profile.get('name', '') if profile else '',
            'interests': profile.get('interests', []) if profile else [],
        }
        if include_contact:
            member['contact_info'] = get_contact_info(uid)
        members.append(member)
    return members


def _get_available_profiles(exclude_user_ids=None):
    """Load all profiles except those that should be excluded.

    In production this would query Datastore for all profiles.
    For now we import the query helper.
    """
    from google.cloud import datastore as _ds
    _client = _ds.Client()
    query = _client.query(kind='Profile')
    results = list(query.fetch())

    exclude = set(int(uid) for uid in (exclude_user_ids or []))
    profiles = {}
    for entity in results:
        uid = entity.key.id_or_name
        if uid in exclude:
            continue
        d = dict(entity)
        d['id'] = uid
        # Only include profiles with a name (complete profiles)
        if d.get('name'):
            profiles[uid] = d
    return profiles


# ── Public API ───────────────────────────────────────────────────────────────

def check_for_signal(user_id):
    """Main entry point — called when user opens Discovery.

    Returns (data, error) where data is one of:
      {'status': 'has_pod', 'pod': {...}, 'members': [...], 'revealed': bool}
      {'status': 'has_signal', 'signal': {...}, 'members': [...]}
      {'status': 'new_signal', 'signal': {...}, 'members': [...]}
      {'status': 'no_match'}
    """
    # Must have a complete profile
    profile = get_profile(user_id)
    if not profile or not profile.get('name'):
        return None, 'Complete your profile before discovering signals'

    # 1. Check for active (unexpired) pod
    pod = _db_get_active_pod(user_id)
    if pod and not _is_expired(pod):
        members = _get_member_profiles(
            pod.get('members', []),
            include_contact=pod.get('revealed', False),
        )
        return {
            'status': 'has_pod',
            'pod': pod,
            'members': members,
            'revealed': pod.get('revealed', False),
        }, None

    # 2. Check for pending (unexpired) signal
    signal = get_signal_for_user(user_id)
    if signal and not _is_expired(signal):
        members = _get_member_profiles(signal.get('target_user_ids', []))
        return {
            'status': 'has_signal',
            'signal': signal,
            'members': members,
        }, None

    # 3. Try to find a new signal cluster
    all_profiles = _get_available_profiles()
    # Make sure the requester's profile is in the pool
    if user_id not in all_profiles:
        all_profiles[user_id] = profile

    cluster = find_signal_cluster(user_id, all_profiles)

    if not cluster:
        return {'status': 'no_match'}, None

    # Create the signal
    signal = _db_create_signal(user_id, cluster)
    members = _get_member_profiles(cluster)

    return {
        'status': 'new_signal',
        'signal': signal,
        'members': members,
    }, None


def accept_signal(user_id, signal_id):
    """User accepts a signal invite.

    Returns (data, error).
    """
    signal = _db_get_signal(signal_id)
    if not signal:
        return None, 'Signal not found'

    # Check the user is a target
    targets = signal.get('target_user_ids', [])
    if int(user_id) not in [int(t) for t in targets]:
        return None, 'You are not part of this signal'

    # Check expiration
    if _is_expired(signal):
        return None, 'This signal has expired'

    # Check already accepted status
    if signal.get('status') == 'accepted':
        return None, 'This signal has already been fully accepted'

    # Record acceptance
    updated = _db_accept_signal(signal_id, user_id)
    if not updated:
        return None, 'Failed to accept signal'

    # Check if everyone accepted → create pod
    accepted = set(int(uid) for uid in updated.get('accepted_user_ids', []))
    target_set = set(int(uid) for uid in targets)

    if accepted >= target_set:
        # All accepted → convert to pod
        pod = create_pod_from_signal(updated)
        members = _get_member_profiles(pod.get('members', []))
        return {
            'status': 'has_pod',
            'pod': pod,
            'members': members,
            'revealed': False,
        }, None

    # Still waiting for others
    members = _get_member_profiles(targets)
    return {
        'status': 'has_signal',
        'signal': updated,
        'members': members,
    }, None


def update_contact_info(user_id, data):
    """User updates their revealable contact info.

    Returns (data, error).
    """
    if not data:
        return None, 'No contact info provided'

    instagram = data.get('instagram')
    phone = data.get('phone')

    if not instagram and not phone:
        return None, 'Provide at least instagram or phone'

    result = _db_upsert_contact_info(user_id, data)
    return result, None
