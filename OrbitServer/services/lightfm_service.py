"""
LightFM collaborative filtering service.

Trains a recommendation model on all UserHistory records using WARP loss
(Weighted Approximate-Rank Pairwise), which is well-suited for implicit
feedback (joins/browsed as positives, skipped excluded).

The model learns latent embeddings for both users and missions, incorporating
side features (user interests, college year, mission tags) to handle cold-start.
It improves as more users interact with more missions.

Usage:
  - get_lightfm_scores(user_id, mission_ids) -> {mission_id: float}
  - retrain() -- call from a cron endpoint to refresh with new data

The model is lazy-trained on the first scoring call and kept in memory.
Unknown users or missions (not in training data) degrade gracefully to 0.0.
"""

import logging
import math
import threading

import numpy as np
from lightfm import LightFM
from lightfm.data import Dataset

from OrbitServer.models.models import list_all_history, list_missions, list_all_users

logger = logging.getLogger(__name__)

# Interaction weights by action type
INTERACTION_WEIGHTS = {
    'joined':  1.0,
    'browsed': 0.3,
    'skipped': 0.0,   # excluded from positive signal
}
ATTENDED_BONUS = 0.5   # added to joined weight when attended=True
MIN_INTERACTIONS = 10  # minimum records before training is worthwhile

_model = None
_dataset = None
_lock = threading.Lock()
_trained = False


def _sigmoid(x: float) -> float:
    """Map a raw LightFM score to (0, 1)."""
    return 1.0 / (1.0 + math.exp(-float(x)))


def _train():
    """Build feature matrices and fit the LightFM model. Called inside _lock."""
    global _model, _dataset, _trained

    history = list_all_history()
    if len(history) < MIN_INTERACTIONS:
        logger.info("LightFM: not enough interaction data (%d records), skipping training", len(history))
        return

    missions = list_missions()
    users = list_all_users()

    # Collect all user and mission IDs present in history
    user_ids = {int(h['user_id']) for h in history if h.get('user_id') is not None}
    mission_ids = {int(m['id']) for m in missions if m.get('id') is not None}

    # User side features: interests + college year
    user_feature_map = {}
    for u in users:
        uid = u.get('id')
        if uid is None or int(uid) not in user_ids:
            continue
        feats = [f"interest:{i}" for i in (u.get('interests') or [])]
        if u.get('college_year'):
            feats.append(f"year:{u['college_year']}")
        if feats:
            user_feature_map[int(uid)] = feats

    # Item side features: mission tags
    item_feature_map = {}
    for m in missions:
        mid = m.get('id')
        if mid is None:
            continue
        feats = [f"tag:{t}" for t in (m.get('tags') or [])]
        if feats:
            item_feature_map[int(mid)] = feats

    all_user_feats = list({f for feats in user_feature_map.values() for f in feats})
    all_item_feats = list({f for feats in item_feature_map.values() for f in feats})

    dataset = Dataset()
    dataset.fit(
        users=user_ids,
        items=mission_ids,
        user_features=all_user_feats or None,
        item_features=all_item_feats or None,
    )

    # Build interaction triples (user_id, mission_id, weight)
    triples = []
    for h in history:
        uid = h.get('user_id')
        mid = h.get('mission_id')
        action = h.get('action', '')
        if uid is None or mid is None:
            continue
        w = INTERACTION_WEIGHTS.get(action, 0.0)
        if action == 'joined' and h.get('attended') is True:
            w += ATTENDED_BONUS
        if w > 0:
            triples.append((int(uid), int(mid), w))

    if not triples:
        logger.info("LightFM: no positive interactions found, skipping training")
        return

    interactions_matrix, weights_matrix = dataset.build_interactions(triples)

    ufm = dataset.build_user_features(
        [(uid, feats) for uid, feats in user_feature_map.items()]
    ) if user_feature_map else None

    ifm = dataset.build_item_features(
        [(mid, feats) for mid, feats in item_feature_map.items()]
    ) if item_feature_map else None

    model = LightFM(loss='warp', no_components=32, random_state=42)
    model.fit(
        interactions_matrix,
        sample_weight=weights_matrix,
        user_features=ufm,
        item_features=ifm,
        epochs=20,
        num_threads=2,
        verbose=False,
    )

    _model = model
    _dataset = dataset
    _trained = True
    logger.info("LightFM: trained on %d interactions (%d users, %d missions)",
                len(triples), len(user_ids), len(mission_ids))


def _get_model():
    """Lazy-load the model on first call (thread-safe, double-checked)."""
    global _trained
    if not _trained:
        with _lock:
            if not _trained:
                try:
                    _train()
                except Exception:
                    logger.exception("LightFM training failed")
    return _model, _dataset


def get_lightfm_scores(user_id: int, mission_ids: list) -> dict:
    """
    Return LightFM predicted scores for a user against a list of mission IDs.
    Returns {mission_id: float in (0, 1)} via sigmoid normalization.
    Unknown users or missions degrade to 0.0.
    """
    if not mission_ids:
        return {}

    model, dataset = _get_model()
    if model is None or dataset is None:
        return {mid: 0.0 for mid in mission_ids}

    try:
        uid_map, _, iid_map, _ = dataset.mapping()
        user_id = int(user_id)

        if user_id not in uid_map:
            return {mid: 0.0 for mid in mission_ids}

        internal_uid = uid_map[user_id]

        known = [(mid, iid_map[mid]) for mid in mission_ids if mid in iid_map]
        result = {mid: 0.0 for mid in mission_ids}

        if not known:
            return result

        known_mids, internal_iids = zip(*known)
        raw_scores = model.predict(internal_uid, np.array(internal_iids))

        for mid, raw in zip(known_mids, raw_scores):
            result[mid] = _sigmoid(raw)

        return result

    except Exception:
        logger.exception("LightFM scoring failed")
        return {mid: 0.0 for mid in mission_ids}


def retrain():
    """
    Force a full retrain from current Datastore data.
    Call from a scheduled cron endpoint (e.g. nightly) to keep the model fresh.
    """
    global _trained
    with _lock:
        _trained = False
        try:
            _train()
        except Exception:
            logger.exception("LightFM retrain failed")
