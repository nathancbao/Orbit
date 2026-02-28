from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.utils.rate_limit import limiter
from OrbitServer.utils.validators import validate_message_data, validate_vote_data
from OrbitServer.services.chat_service import (
    get_messages, send_message, create_poll, respond_to_vote, get_votes_for_pod,
)

chat_bp = Blueprint('chat', __name__, url_prefix='/api/pods')


@chat_bp.route('/<pod_id>/messages', methods=['GET'])
@require_auth
def messages(pod_id):
    msgs, err = get_messages(pod_id, g.user_id)
    if err:
        status = 403 if "not a member" in err.lower() else 404
        return error(err, status)
    return success(msgs)


@chat_bp.route('/<pod_id>/messages', methods=['POST'])
@limiter.limit("30 per minute")
@require_auth
def post_message(pod_id):
    data = request.get_json(silent=True) or {}

    valid, errors = validate_message_data(data)
    if not valid:
        return error(errors, 400)

    msg, err = send_message(pod_id, g.user_id, data['content'])
    if err:
        status = 400 if "prohibited" in err.lower() or "not a member" in err.lower() else 404
        return error(err, status)
    return success(msg, 201)


@chat_bp.route('/<pod_id>/votes', methods=['GET'])
@require_auth
def list_votes(pod_id):
    votes, err = get_votes_for_pod(pod_id, g.user_id)
    if err:
        status = 403 if "not a member" in err.lower() else 404
        return error(err, status)
    return success(votes)


@chat_bp.route('/<pod_id>/votes', methods=['POST'])
@require_auth
def create_vote_route(pod_id):
    data = request.get_json(silent=True) or {}

    valid, errors = validate_vote_data(data)
    if not valid:
        return error(errors, 400)

    vote, err = create_poll(pod_id, g.user_id, data['vote_type'], data['options'])
    if err:
        status = 400 if "not a member" in err.lower() or "already" in err.lower() else 404
        return error(err, status)
    return success(vote, 201)


@chat_bp.route('/<pod_id>/votes/<vote_id>/respond', methods=['POST'])
@require_auth
def respond(pod_id, vote_id):
    data = request.get_json(silent=True) or {}
    option_index = data.get('option_index')
    if option_index is None or not isinstance(option_index, int):
        return error("option_index must be an integer", 400)

    vote, err = respond_to_vote(pod_id, vote_id, g.user_id, option_index)
    if err:
        return error(err, 400)
    return success(vote)
