from flask import Blueprint, g, request

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.signals.service import (
    check_for_signal,
    accept_signal,
    update_contact_info,
)

signals_bp = Blueprint('signals', __name__, url_prefix='/api/signals')


@signals_bp.route('/signal', methods=['GET'])
@require_auth
def check_signal():
    """Check for active pods, pending signals, or generate new signal."""
    data, err = check_for_signal(g.user_id)
    if err:
        return error(err)
    return success(data)


@signals_bp.route('/signal/<signal_id>/accept', methods=['POST'])
@require_auth
def accept(signal_id):
    """Accept a signal invite."""
    data, err = accept_signal(g.user_id, signal_id)
    if err:
        return error(err)
    return success(data)


@signals_bp.route('/contact-info', methods=['POST'])
@require_auth
def update_contact():
    """Update user's revealable contact info."""
    body = request.get_json(silent=True) or {}
    data, err = update_contact_info(g.user_id, body)
    if err:
        return error(err)
    return success(data)
