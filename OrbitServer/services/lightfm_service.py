"""
LightFM collaborative filtering service.

Trains a recommendation model on all UserEventHistory records using WARP loss
(Weighted Approximate-Rank Pairwise), which is well-suited for implicit
feedback (joins/browsed as positives, skipped excluded).

The model learns latent embeddings for both users and events, incorporating
side features (user interests, college year, event tags) to handle cold-start.
It improves as more users interact with more events.

Usage:
  - get_lightfm_scores(user_id, event_ids) -> {event_id: float}
  - retrain() — call from a cron endpoint to refresh with new data

The model is lazy-trained on the first scoring call and kept in memory.
Unknown users or events (not in training data) degrade gracefully to 0.0.
"""

import logging
import math
import threading

import numpy as np
from lightfm import LightFM
from lightfm.data import Dataset

from OrbitServer.models.models import list_all_event_history, list_events, list_all_profiles

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

    history = list_all_event_history()
    if len(history) < MIN_INTERACTIONS:
        logger.info("LightFM: not enough interaction data (%d records), skipping training", len(history))
        return

    events = list_events()
    profiles = list_all_profiles()

    # Collect all user and event IDs present in history
    user_ids = {int(h['user_id']) for h in history if h.get('user_id') is not None}
    event_ids = {int(e['id']) for e in events if e.get('id') is not None}

    # User side features: interests + college year
    user_feature_map = {}
    for p in profiles:
        uid = p.get('user_id') or p.get('id')
        if uid is None or int(uid) not in user_ids:
            continue
        feats = [f"interest:{i}" for i in (p.get('interests') or [])]
        if p.get('college_year'):
            feats.append(f"year:{p['college_year']}")
        if feats:
            user_feature_map[int(uid)] = feats

    # Item side features: event tags
    item_feature_map = {}
    for e in events:
        eid = e.get('id')
        if eid is None:
            continue
        feats = [f"tag:{t}" for t in (e.get('tags') or [])]
        if feats:
            item_feature_map[int(eid)] = feats

    all_user_feats = list({f for feats in user_feature_map.values() for f in feats})
    all_item_feats = list({f for feats in item_feature_map.values() for f in feats})

    dataset = Dataset()
    dataset.fit(
        users=user_ids,
        items=event_ids,
        user_features=all_user_feats or None,
        item_features=all_item_feats or None,
    )

    # Build interaction triples (user_id, event_id, weight)
    triples = []
    for h in history:
        uid = h.get('user_id')
        eid = h.get('event_id')
        action = h.get('action', '')
        if uid is None or eid is None:
            continue
        w = INTERACTION_WEIGHTS.get(action, 0.0)
        if action == 'joined' and h.get('attended') is True:
            w += ATTENDED_BONUS
        if w > 0:
            triples.append((int(uid), int(eid), w))

    if not triples:
        logger.info("LightFM: no positive interactions found, skipping training")
        return

    interactions_matrix, weights_matrix = dataset.build_interactions(triples)

    ufm = dataset.build_user_features(
        [(uid, feats) for uid, feats in user_feature_map.items()]
    ) if user_feature_map else None

    ifm = dataset.build_item_features(
        [(eid, feats) for eid, feats in item_feature_map.items()]
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
    logger.info("LightFM: trained on %d interactions (%d users, %d events)",
                len(triples), len(user_ids), len(event_ids))


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


def get_lightfm_scores(user_id: int, event_ids: list) -> dict:
    """
    Return LightFM predicted scores for a user against a list of event IDs.
    Returns {event_id: float in (0, 1)} via sigmoid normalization.
    Unknown users or events degrade to 0.0.
    """
    if not event_ids:
        return {}

    model, dataset = _get_model()
    if model is None or dataset is None:
        return {eid: 0.0 for eid in event_ids}

    try:
        uid_map, _, iid_map, _ = dataset.mapping()
        user_id = int(user_id)

        if user_id not in uid_map:
            return {eid: 0.0 for eid in event_ids}

        internal_uid = uid_map[user_id]

        known = [(eid, iid_map[eid]) for eid in event_ids if eid in iid_map]
        result = {eid: 0.0 for eid in event_ids}

        if not known:
            return result

        known_eids, internal_iids = zip(*known)
        raw_scores = model.predict(internal_uid, np.array(internal_iids))

        for eid, raw in zip(known_eids, raw_scores):
            result[eid] = _sigmoid(raw)

        return result

    except Exception:
        logger.exception("LightFM scoring failed")
        return {eid: 0.0 for eid in event_ids}


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
