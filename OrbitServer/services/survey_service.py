"""
Post-activity survey service.

Orchestrates storing survey responses, updating user interests,
adjusting trust scores from member votes, and enriching UserHistory
with enjoyment ratings for the ML recommendation engine.
"""

import logging

from OrbitServer.models.models import (
    get_pod, get_user, update_user, create_survey_response,
    get_user_survey_for_pod, get_history_entry, update_history,
    adjust_trust_score, transactional_pod_update,
)

logger = logging.getLogger(__name__)

MAX_INTERESTS = 10
UPVOTE_DELTA = 0.1
DOWNVOTE_DELTA = -0.15


def submit_survey(user_id, pod_id, enjoyment_rating, added_interests, member_votes):
    """
    Process a post-activity survey submission.

    Side effects:
      1. Store the SurveyResponse entity
      2. Merge selected tags into user's interests (capped at MAX_INTERESTS)
      3. Adjust trust scores for voted-on pod members
      4. Enrich UserHistory with attended=True and enjoyment_rating
      5. Add user to pod's survey_completed_by list

    Returns (result_dict, error_string).
    """
    uid = int(user_id)

    # ── Validate pod membership ────────────────────────────────────────────
    pod = get_pod(pod_id)
    if not pod:
        return None, "Pod not found"
    if pod.get('status') != 'completed':
        return None, "Survey is only available for completed activities"
    if uid not in (pod.get('member_ids') or []):
        return None, "You are not a member of this pod"

    # ── Prevent duplicate submissions ──────────────────────────────────────
    existing = get_user_survey_for_pod(uid, pod_id)
    if existing:
        return None, "You have already submitted a survey for this pod"

    # ── Validate inputs ────────────────────────────────────────────────────
    if not isinstance(enjoyment_rating, int) or enjoyment_rating < 1 or enjoyment_rating > 5:
        return None, "enjoyment_rating must be an integer between 1 and 5"

    added_interests = list(added_interests or [])
    member_votes = dict(member_votes or {})

    # Validate member_votes: keys must be pod members (not self), values "up"/"down"
    pod_member_ids = set(pod.get('member_ids') or [])
    for target_str, vote in member_votes.items():
        try:
            target_id = int(target_str)
        except (ValueError, TypeError):
            return None, f"Invalid member ID in member_votes: {target_str}"
        if target_id == uid:
            return None, "You cannot vote for yourself"
        if target_id not in pod_member_ids:
            return None, f"User {target_id} is not a member of this pod"
        if vote not in ('up', 'down'):
            return None, f"Invalid vote value: {vote}. Must be 'up' or 'down'"

    # ── 1. Store survey response ───────────────────────────────────────────
    mission_id = pod.get('mission_id')
    survey = create_survey_response(
        user_id=uid,
        pod_id=pod_id,
        mission_id=mission_id,
        enjoyment_rating=enjoyment_rating,
        added_interests=added_interests,
        member_votes=member_votes,
    )

    # ── 2. Merge interests ─────────────────────────────────────────────────
    if added_interests:
        user = get_user(uid) or {}
        current = list(user.get('interests') or [])
        current_lower = {i.lower() for i in current}
        for tag in added_interests:
            if len(current) >= MAX_INTERESTS:
                break
            if tag.lower() not in current_lower:
                current.append(tag)
                current_lower.add(tag.lower())
        update_user(uid, {'interests': current})

    # ── 3. Adjust trust scores ─────────────────────────────────────────────
    for target_str, vote in member_votes.items():
        target_id = int(target_str)
        delta = UPVOTE_DELTA if vote == 'up' else DOWNVOTE_DELTA
        adjust_trust_score(target_id, delta)

    # ── 4. Enrich UserHistory ──────────────────────────────────────────────
    if mission_id is not None:
        history_entry = get_history_entry(uid, int(mission_id))
        if history_entry:
            update_history(history_entry['id'], {
                'attended': True,
                'enjoyment_rating': enjoyment_rating,
            })

    # ── 5. Mark survey as completed on pod ─────────────────────────────────
    def _mark_survey_done(entity):
        completed_by = list(entity.get('survey_completed_by') or [])
        if uid not in completed_by:
            completed_by.append(uid)
        entity['survey_completed_by'] = completed_by

    transactional_pod_update(pod_id, _mark_survey_done)

    return {'survey_id': survey['id'], 'message': 'Survey submitted successfully'}, None
