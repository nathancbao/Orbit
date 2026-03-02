from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.utils.rate_limit import limiter
from OrbitServer.utils.validators import validate_signal_data
from OrbitServer.services.signal_service import (
    create_new_signal, get_user_signals, get_all_signals,
    remove_signal, rsvp_signal,
)

signals_bp = Blueprint('signals', __name__, url_prefix='/api/signals')


# ── GET /signals ─────────────────────────────────────────────────────────────
# Returns all signals created by the authenticated user.

@signals_bp.route('', methods=['GET'])
@require_auth
def list_signals():
    signals, err = get_user_signals(g.user_id)
    if err:
        return error(err, 500)
    return success(signals)


# ── GET /signals/discover ────────────────────────────────────────────────────
# Returns all signals (discover feed for all users).

@signals_bp.route('/discover', methods=['GET'])
@require_auth
def discover():
    signals, err = get_all_signals(g.user_id)
    if err:
        return error(err, 500)
    return success(signals)


# ── POST /signals ────────────────────────────────────────────────────────────
# Create a new signal.
# Swift body (snake_case):
#   activity_category, custom_activity_name?, min_group_size, max_group_size,
#   availability: [{"date": "<ISO8601>", "time_blocks": ["morning", ...]}],
#   description?

@signals_bp.route('', methods=['POST'])
@limiter.limit("10 per minute")
@require_auth
def create():
    data = request.get_json(silent=True) or {}

    valid, errors = validate_signal_data(data)
    if not valid:
        return error(errors, 400)

    signal, err = create_new_signal(data, g.user_id)
    if err:
        return error(err, 500)
    return success(signal, 201)


# ── DELETE /signals/<id> ─────────────────────────────────────────────────────
# Delete a signal. Only the creator can delete.

@signals_bp.route('/<signal_id>', methods=['DELETE'])
@require_auth
def delete(signal_id):
    result, err, status_code = remove_signal(signal_id, g.user_id)
    if err:
        return error(err, status_code)
    return success({"message": "Signal deleted"})


# ── POST /signals/<id>/rsvp ─────────────────────────────────────────────────
# "I'm Down" -- add the authenticated user to the signal's rsvps list.

@signals_bp.route('/<signal_id>/rsvp', methods=['POST'])
@require_auth
def rsvp(signal_id):
    try:
        signal, err = rsvp_signal(signal_id, g.user_id)
    except Exception:
        return error("RSVP failed, please try again", 500)
    if err:
        status_code = 404 if "not found" in err.lower() else 409
        return error(err, status_code)
    return success(signal)
