"""
Notification suggestion endpoint.

Returns AI-recommended missions formatted as push notification payloads.
The Swift client can call this periodically (or via background fetch) to
decide what notification to display.
"""

import logging

from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.services.ai_suggestion_service import get_suggested_missions

logger = logging.getLogger(__name__)

notifications_bp = Blueprint('notifications', __name__, url_prefix='/api/notifications')


@notifications_bp.route('/suggested', methods=['GET'])
@require_auth
def suggested_notification():
    """Return a single AI-recommended mission formatted for a push notification.

    Response:
        {
          "notification": {
            "title": "You might like: Hiking at Lake Berryessa",
            "body": "Because you like Outdoors, Fitness",
            "mission_id": "12345",
            "mission_title": "Hiking at Lake Berryessa",
            "match_score": 0.82,
            "suggestion_reason": "Because you like Outdoors, Fitness"
          }
        }

    Returns {"notification": null} when there's nothing to suggest.
    """
    try:
        missions = get_suggested_missions(g.user_id, limit=1)
    except Exception:
        logger.exception("Failed to get notification suggestion")
        return success({"notification": None})

    if not missions:
        return success({"notification": None})

    top = missions[0]
    reason = top.get('suggestion_reason', 'Something new to try')
    notification = {
        "title": f"You might like: {top.get('title', 'a new mission')}",
        "body": reason,
        "mission_id": top['id'],
        "mission_title": top.get('title', ''),
        "match_score": top.get('match_score', 0.0),
        "suggestion_reason": reason,
    }

    return success({"notification": notification})
