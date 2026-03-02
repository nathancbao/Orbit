"""
Notification service — creates in-app notifications and sends APNs pushes.

All public notify_* functions are fire-and-forget: they run on a background
thread so they never block the request handler. If APNs is not configured
(missing env vars), notifications are still saved to Datastore — push is
simply skipped.
"""

import logging
import os
import threading

from OrbitServer.models.models import (
    create_notification, get_event_pod, get_profile, get_device_tokens,
)

logger = logging.getLogger(__name__)

# ── APNs configuration (optional) ───────────────────────────────────────────

_apns_client = None
_apns_lock = threading.Lock()

APNS_KEY_ID = os.environ.get('APNS_KEY_ID')
APNS_TEAM_ID = os.environ.get('APNS_TEAM_ID')
APNS_KEY_PATH = os.environ.get('APNS_KEY_PATH')
APNS_BUNDLE_ID = os.environ.get('APNS_BUNDLE_ID', 'com.orbit.app')
APNS_USE_SANDBOX = os.environ.get('APNS_USE_SANDBOX', '1') == '1'


def _get_apns_client():
    """Lazy-load the APNs client. Returns None if not configured."""
    global _apns_client
    if _apns_client is not None:
        return _apns_client
    if not (APNS_KEY_ID and APNS_TEAM_ID and APNS_KEY_PATH):
        return None
    with _apns_lock:
        if _apns_client is not None:
            return _apns_client
        try:
            from apns2.client import APNsClient
            from apns2.credentials import TokenCredentials
            credentials = TokenCredentials(
                auth_key_path=APNS_KEY_PATH,
                auth_key_id=APNS_KEY_ID,
                team_id=APNS_TEAM_ID,
            )
            _apns_client = APNsClient(
                credentials=credentials,
                use_sandbox=APNS_USE_SANDBOX,
            )
            logger.info("APNs client initialized")
        except Exception:
            logger.exception("Failed to initialize APNs client")
    return _apns_client


def _send_push(user_id, title, body, data=None):
    """Send a push notification to all devices registered for user_id."""
    apns = _get_apns_client()
    if apns is None:
        return

    tokens = get_device_tokens(user_id)
    if not tokens:
        return

    try:
        from apns2.payload import Payload
        payload = Payload(
            alert={'title': title, 'body': body},
            sound='default',
            badge=None,
            custom=data or {},
        )
        for token in tokens:
            try:
                apns.send_notification(token, payload, APNS_BUNDLE_ID)
            except Exception:
                logger.warning("APNs send failed for token %s...", token[:8])
    except Exception:
        logger.exception("APNs push failed for user %s", user_id)


def _fire_and_forget(fn, *args, **kwargs):
    """Run fn on a daemon thread so it doesn't block the request."""
    def _run():
        try:
            fn(*args, **kwargs)
        except Exception:
            logger.exception("Background notification failed")
    t = threading.Thread(target=_run, daemon=True)
    t.start()


def _user_display_name(user_id):
    """Get a user's display name, falling back to 'Someone'."""
    profile = get_profile(user_id)
    if profile and profile.get('name'):
        return profile['name']
    return 'Someone'


# ── Public notification triggers ─────────────────────────────────────────────

def notify_pod_join(pod_id, joiner_user_id):
    """Notify all other pod members that someone joined."""
    def _do():
        pod = get_event_pod(pod_id)
        if not pod:
            return
        name = _user_display_name(joiner_user_id)
        title = "New pod member"
        body = f"{name} joined your pod"
        data = {'pod_id': str(pod_id), 'event_id': str(pod.get('event_id', ''))}

        for mid in (pod.get('member_ids') or []):
            if mid != int(joiner_user_id):
                create_notification(mid, 'pod_join', title, body, data)
                _send_push(mid, title, body, data)

    _fire_and_forget(_do)


def notify_pod_leave(pod_id, leaver_user_id, remaining_member_ids):
    """Notify remaining pod members that someone left.

    remaining_member_ids is passed explicitly because the leaver may already
    be removed from the pod entity by the time this runs.
    """
    def _do():
        name = _user_display_name(leaver_user_id)
        title = "Pod member left"
        body = f"{name} left your pod"
        pod = get_event_pod(pod_id)
        data = {'pod_id': str(pod_id)}
        if pod:
            data['event_id'] = str(pod.get('event_id', ''))

        for mid in remaining_member_ids:
            if mid != int(leaver_user_id):
                create_notification(mid, 'pod_leave', title, body, data)
                _send_push(mid, title, body, data)

    _fire_and_forget(_do)


def notify_chat_message(pod_id, sender_user_id, preview):
    """Notify pod members (except sender) of a new chat message."""
    def _do():
        pod = get_event_pod(pod_id)
        if not pod:
            return
        name = _user_display_name(sender_user_id)
        title = f"{name}"
        body = preview if len(preview) <= 100 else preview[:97] + '...'
        data = {'pod_id': str(pod_id), 'event_id': str(pod.get('event_id', ''))}

        for mid in (pod.get('member_ids') or []):
            if mid != int(sender_user_id):
                create_notification(mid, 'chat_message', title, body, data)
                _send_push(mid, title, body, data)

    _fire_and_forget(_do)


def notify_recommended_events(user_id, events):
    """Create a notification for AI-recommended events."""
    def _do():
        if not events:
            return
        count = len(events)
        title = "Events for you"
        body = f"We found {count} event{'s' if count > 1 else ''} you might like"
        event_ids = [str(e.get('id', '')) for e in events[:5]]
        data = {'event_ids': ','.join(event_ids)}
        create_notification(user_id, 'recommended_event', title, body, data)
        _send_push(user_id, title, body, data)

    _fire_and_forget(_do)
