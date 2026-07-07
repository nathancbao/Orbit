"""Analytics event emission (Batch G).

Implements the Datastore-only v1 of the taxonomy in
``docs/analytics-and-metrics.md``: build a common event envelope, pseudonymize
the user, and append it to the ``AnalyticsEvent`` kind. The stream is designed
to migrate to BigQuery later (§3 of the design) without changing call sites —
callers only ever touch ``emit`` / ``ingest_batch``.

Two entry points:

* ``emit(...)`` — server-authoritative events (``mission_joined``,
  ``survey_submitted``, …). Called from service code at the moment of truth.
* ``ingest_batch(...)`` — client-reported engagement events (``app_opened``,
  ``mission_viewed``, …) arriving via ``POST /api/analytics/events``.

**Best-effort:** analytics must never break a core flow. Emission catches and
logs its own errors; it does not propagate exceptions to the caller.
"""

import datetime
import logging
import uuid

from OrbitServer.models.models import create_analytics_event
from OrbitServer.utils.analytics_id import pseudonymize

logger = logging.getLogger(__name__)

# The event catalog from docs/analytics-and-metrics.md §2. Ingestion rejects
# anything not on this list so a compromised or buggy client can't pollute the
# stream with arbitrary event names.
ALLOWED_EVENTS = frozenset({
    'app_opened',
    'signup_completed',
    'profile_completed',
    'mission_viewed',
    'mission_joined',
    'mission_left',
    'mission_skipped',
    'pod_meeting_confirmed',
    'attendance_confirmed',
    'mission_completed',
    'survey_submitted',
    'signal_created',
    'signal_rsvped',
    'friend_request_sent',
    'friend_accepted',
    'chat_message_sent',
    'notification_opened',
})

# Cap on how many events a single ingest call may carry, to bound the work and
# blast radius of one request.
MAX_BATCH_SIZE = 100

_MAX_PROPERTIES = 32


def _now_iso():
    return datetime.datetime.utcnow().replace(microsecond=0).isoformat() + 'Z'


def _sanitize_properties(properties):
    """Coerce a properties map into something safe to persist.

    Drops non-dict input and caps the number of keys so a client can't send an
    unbounded payload. Values are stored as-is (the model excludes the map from
    indexes, so shape is unconstrained), but we never store raw content here by
    convention — callers pass IDs and counts, not payloads.
    """
    if not isinstance(properties, dict):
        return {}
    if len(properties) > _MAX_PROPERTIES:
        # Keep a bounded, deterministic subset rather than rejecting outright.
        return {k: properties[k] for k in sorted(properties)[:_MAX_PROPERTIES]}
    return dict(properties)


def _build_envelope(event_name, user_id, properties, *, event_id, ts,
                    session_id, platform, app_version, received_ts):
    """Assemble the common event envelope (design §2).

    The server always stamps ``received_ts`` and derives ``user_pseudo_id`` from
    the authenticated ``user_id`` — client-supplied identity is never trusted.
    """
    return {
        'event_name': event_name,
        'event_id': event_id or uuid.uuid4().hex,
        'ts': ts or received_ts,
        'received_ts': received_ts,
        'user_pseudo_id': pseudonymize(user_id),
        'session_id': session_id,
        'platform': platform,
        'app_version': app_version,
        'properties': _sanitize_properties(properties),
    }


def emit(event_name, user_id, properties=None, *, event_id=None, ts=None,
         session_id=None, platform='server', app_version=None):
    """Emit one server-authoritative event. Best-effort — never raises.

    Returns the stored ``event_id`` on success, or ``None`` if the event was
    rejected or the write failed (logged, not raised).
    """
    try:
        if event_name not in ALLOWED_EVENTS:
            logger.warning("Dropping unknown analytics event: %s", event_name)
            return None
        envelope = _build_envelope(
            event_name, user_id, properties or {},
            event_id=event_id, ts=ts, session_id=session_id,
            platform=platform, app_version=app_version,
            received_ts=_now_iso(),
        )
        return create_analytics_event(envelope)
    except Exception:
        # Analytics is non-critical: log and move on so the caller's core flow
        # (a join, a survey submit, …) is never broken by an emission failure.
        logger.exception("Failed to emit analytics event %s", event_name)
        return None


def ingest_batch(user_id, raw_events, *, platform='ios'):
    """Ingest a batch of client-reported events. Best-effort — never raises.

    Each raw event is validated against the catalog, re-stamped server-side, and
    pseudonymized under the *authenticated* ``user_id`` (any client-supplied
    identity is ignored). Returns ``(accepted, rejected)`` counts.
    """
    accepted = 0
    rejected = 0
    if not isinstance(raw_events, list):
        return accepted, rejected

    for raw in raw_events[:MAX_BATCH_SIZE]:
        try:
            if not isinstance(raw, dict):
                rejected += 1
                continue
            event_name = raw.get('event_name')
            if event_name not in ALLOWED_EVENTS:
                rejected += 1
                continue
            envelope = _build_envelope(
                event_name, user_id, raw.get('properties') or {},
                event_id=raw.get('event_id'),
                ts=raw.get('ts'),
                session_id=raw.get('session_id'),
                platform=platform,
                app_version=raw.get('app_version'),
                received_ts=_now_iso(),
            )
            create_analytics_event(envelope)
            accepted += 1
        except Exception:
            logger.exception("Failed to ingest a client analytics event")
            rejected += 1

    return accepted, rejected
