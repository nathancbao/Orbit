"""Analytics ingestion endpoint (Batch G).

The iOS client buffers engagement events and flushes them here as a batch on
app foreground/background. The server owns identity and timing: it stamps
``received_ts`` and derives ``user_pseudo_id`` from the authenticated user, so a
client can only report events *as itself*. See docs/analytics-and-metrics.md.
"""

from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.utils.rate_limit import limiter
from OrbitServer.services.analytics_service import ingest_batch, MAX_BATCH_SIZE

analytics_bp = Blueprint('analytics', __name__, url_prefix='/api/analytics')


@analytics_bp.route('/events', methods=['POST'])
@require_auth
@limiter.limit("60 per minute")
def post_events():
    """Ingest a batch of client-reported analytics events.

    Body: ``{"events": [ {event_name, event_id, ts, session_id, app_version,
    properties}, ... ]}``. Unknown event names and malformed entries are
    dropped, not fatal — the endpoint reports how many were accepted so the
    client can clear its buffer.
    """
    data = request.get_json(silent=True) or {}
    events = data.get('events')
    if not isinstance(events, list):
        return error("Request body must include an 'events' array", 400)
    if len(events) > MAX_BATCH_SIZE:
        return error(f"Too many events in one batch (max {MAX_BATCH_SIZE})", 400)

    accepted, rejected = ingest_batch(g.user_id, events)
    return success({"accepted": accepted, "rejected": rejected})
