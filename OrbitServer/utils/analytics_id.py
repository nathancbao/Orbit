"""Pseudonymous analytics identifiers.

Analytics never stores a raw ``user_id`` or email. Instead every event carries a
``user_pseudo_id = HMAC-SHA256(user_id, ANALYTICS_SALT)`` — a stable,
non-reversible token that lets us join a user's events together (and honour
deletion/export requests) without holding directly-identifying data in the
analytics store.

The salt is a secret: knowing it lets an attacker re-link pseudo IDs back to
raw user IDs, so it is loaded from the environment with the same prod fail-fast
policy as ``JWT_SECRET`` (see ``utils/auth.py``).
"""

import hashlib
import hmac
import os

_DEV_SALT_FALLBACK = 'dev-analytics-salt-change-me'


def _load_analytics_salt():
    """Resolve the analytics HMAC salt.

    In production (App Engine, ``GAE_ENV`` set) a real salt is mandatory: refuse
    to start rather than pseudonymize with a publicly-known value, which would
    make the pseudo IDs trivially re-identifiable. In local dev the fallback is
    allowed for convenience.
    """
    salt = os.environ.get('ANALYTICS_SALT')
    in_production = bool(os.environ.get('GAE_ENV'))
    if in_production and (not salt or salt == _DEV_SALT_FALLBACK):
        raise RuntimeError(
            "ANALYTICS_SALT is missing or set to the insecure dev default in a "
            "production environment. Set a strong ANALYTICS_SALT before deploying."
        )
    return salt or _DEV_SALT_FALLBACK


_ANALYTICS_SALT = _load_analytics_salt()


def pseudonymize(user_id):
    """Return the stable pseudonymous id for ``user_id``.

    Deterministic: the same ``user_id`` always maps to the same token, so events
    can be grouped per user and a deletion request can recompute the exact slice
    to purge. Not reversible without the salt.
    """
    key = _ANALYTICS_SALT.encode('utf-8')
    msg = str(user_id).encode('utf-8')
    return hmac.new(key, msg, hashlib.sha256).hexdigest()
