"""Scheduled cleanup endpoint, invoked daily by App Engine cron (cron.yaml).

Lazy deletion (on read) remains the primary mechanism; this sweep just
catches entities nobody ever reads so they don't linger in Datastore.
"""

import datetime
import logging

from flask import Blueprint, request

from OrbitServer.utils.responses import success, error
from OrbitServer.models.models import (
    list_missions, delete_pod, client, _entity_to_dict,
)
from OrbitServer.services.mission_service import check_mission_expiration

logger = logging.getLogger(__name__)

tasks_bp = Blueprint('tasks', __name__, url_prefix='/api/tasks')


@tasks_bp.route('/cleanup', methods=['GET'])
def cleanup():
    # App Engine strips this header from external requests, so only real
    # cron (or an admin hitting the app directly on GAE) can trigger it.
    if request.headers.get('X-Appengine-Cron') != 'true':
        return error("Forbidden", 403)

    deleted = {'missions': 0, 'legacy_signals': 0, 'pods': 0}

    try:
        for status in ('open', 'completed'):
            for mission in list_missions(filters={'status': status}):
                if check_mission_expiration(mission) == 'deleted':
                    deleted['missions'] += 1
    except Exception:
        logger.exception("Cleanup: mission sweep failed")

    # One-time purge of the deprecated Signal kind (flex activities now live
    # in Mission). Remove this block once Datastore shows no Signal entities.
    try:
        sig_query = client.query(kind='Signal')
        sig_query.keys_only()
        keys = [entity.key for entity in sig_query.fetch(limit=500)]
        if keys:
            client.delete_multi(keys)
            deleted['legacy_signals'] = len(keys)
    except Exception:
        logger.exception("Cleanup: legacy Signal purge failed")

    try:
        now = datetime.datetime.utcnow()
        pod_query = client.query(kind='Pod')
        for entity in pod_query.fetch(limit=1000):
            pod = _entity_to_dict(entity)
            if not pod:
                continue
            end_raw = pod.get('scheduled_end_time')
            end_dt = None
            if isinstance(end_raw, str):
                try:
                    end_dt = datetime.datetime.fromisoformat(
                        end_raw.replace('Z', '+00:00')
                    ).replace(tzinfo=None)
                except (ValueError, TypeError):
                    end_dt = None
            if end_dt and now > end_dt + datetime.timedelta(hours=24):
                delete_pod(pod['id'])
                deleted['pods'] += 1
    except Exception:
        logger.exception("Cleanup: pod sweep failed")

    logger.info("Cleanup complete: %s", deleted)
    return success(deleted)
