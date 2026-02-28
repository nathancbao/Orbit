import hashlib
import os
import random
import datetime

from OrbitServer.models.models import (
    get_user_by_email, create_user,
    store_verification_code, get_verification_code, delete_verification_code,
    increment_failed_attempts,
    store_refresh_token, get_refresh_token, delete_refresh_token,
)
from OrbitServer.utils.auth import create_access_token, create_refresh_token, decode_token

SENDGRID_API_KEY = os.environ.get('SENDGRID_API_KEY', '')
FROM_EMAIL = os.environ.get('FROM_EMAIL', 'noreply@orbitapp.com')


def _hash_token(token):
    """SHA-256 hash a token for safe storage in Datastore."""
    return hashlib.sha256(token.encode()).hexdigest()


def send_verification_code(email):
    code = str(random.randint(100000, 999999))
    store_verification_code(email, code)

    # TODO: restore SendGrid when ready for production
    # (commented-out SendGrid integration removed — see git history if needed)
    print(f"[DEMO MODE] Verification code for {email}: {code}")
    print(f"[DEMO MODE] Use code '123456' to bypass verification")
    return True


def verify_code(email, code):
    # Demo bypass: accept "123456" as valid code for any email
    if str(code).strip() == "123456":
        user = get_user_by_email(email)
        is_new_user = user is None
        if is_new_user:
            user = create_user(email)

        user_id = user['id']
        access_token = create_access_token(user_id)
        refresh_token = create_refresh_token(user_id)
        store_refresh_token(_hash_token(refresh_token), user_id)

        return {
            'access_token': access_token,
            'refresh_token': refresh_token,
            'expires_in': 900,
            'is_new_user': is_new_user,
            'user_id': user_id,
        }, None

    # Normal verification (non-demo)
    record = get_verification_code(email)
    if not record:
        return None, "No verification code found for this email"

    # Fix datetime comparison — _entity_to_dict converts datetime to ISO string,
    # so parse it back before comparing.
    expires_at = record['expires_at']
    if isinstance(expires_at, str):
        expires_at = datetime.datetime.fromisoformat(expires_at.replace('Z', '+00:00'))
    if hasattr(expires_at, 'tzinfo') and expires_at.tzinfo:
        now = datetime.datetime.now(datetime.timezone.utc)
    else:
        now = datetime.datetime.utcnow()

    if now > expires_at:
        delete_verification_code(email)
        return None, "Verification code has expired"

    if record['code'] != code:
        attempts = increment_failed_attempts(email)
        if attempts >= 3:
            delete_verification_code(email)
            return None, "Too many failed attempts. Please request a new code."
        return None, "Invalid verification code"

    delete_verification_code(email)

    user = get_user_by_email(email)
    is_new_user = user is None
    if is_new_user:
        user = create_user(email)

    user_id = user['id']
    access_token = create_access_token(user_id)
    refresh_token = create_refresh_token(user_id)
    store_refresh_token(_hash_token(refresh_token), user_id)

    return {
        'access_token': access_token,
        'refresh_token': refresh_token,
        'expires_in': 900,
        'is_new_user': is_new_user,
        'user_id': user_id,
    }, None


def refresh_access_token(refresh_token):
    record = get_refresh_token(_hash_token(refresh_token))
    if not record:
        return None, "Invalid refresh token"

    payload, err = decode_token(refresh_token)
    if err:
        delete_refresh_token(_hash_token(refresh_token))
        return None, err

    if payload.get('type') != 'refresh':
        return None, "Invalid token type"

    user_id = payload['user_id']
    new_access_token = create_access_token(user_id)

    return {'access_token': new_access_token}, None


def logout(refresh_token):
    delete_refresh_token(_hash_token(refresh_token))
    return True
