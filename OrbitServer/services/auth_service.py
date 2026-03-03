import hashlib
import logging
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

logger = logging.getLogger(__name__)

SENDGRID_API_KEY = os.environ.get('SENDGRID_API_KEY', '')
FROM_EMAIL = os.environ.get('FROM_EMAIL', 'noreply@orbitapp.com')


def _hash_token(token):
    """SHA-256 hash a token for safe storage in Datastore."""
    return hashlib.sha256(token.encode()).hexdigest()


def _send_email(to_email, subject, html_content):
    """Send an email via SendGrid. Raises on failure."""
    from sendgrid import SendGridAPIClient
    from sendgrid.helpers.mail import Mail

    message = Mail(
        from_email=FROM_EMAIL,
        to_emails=to_email,
        subject=subject,
        html_content=html_content,
    )
    sg = SendGridAPIClient(SENDGRID_API_KEY)
    response = sg.send(message)
    if response.status_code >= 400:
        raise RuntimeError(f"SendGrid returned status {response.status_code}")


def send_verification_code(email):
    code = str(random.randint(100000, 999999))
    store_verification_code(email, code)

    html = (
        '<div style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; '
        'max-width: 480px; margin: 0 auto; padding: 32px;">'
        '<h2 style="color: #1a1a2e; margin-bottom: 8px;">Orbit Verification</h2>'
        '<p style="color: #555; font-size: 16px; line-height: 1.5;">'
        'Your verification code is:</p>'
        f'<div style="background: #f0f0f5; border-radius: 12px; padding: 20px; '
        f'text-align: center; margin: 20px 0;">'
        f'<span style="font-size: 36px; font-weight: 700; letter-spacing: 8px; '
        f'color: #1a1a2e;">{code}</span></div>'
        '<p style="color: #888; font-size: 14px;">This code expires in 10 minutes. '
        'If you didn\'t request this, you can safely ignore this email.</p>'
        '</div>'
    )

    if SENDGRID_API_KEY:
        try:
            _send_email(email, 'Your Orbit Verification Code', html)
            logger.info("Verification email sent to %s", email)
        except Exception:
            logger.exception("SendGrid failed for %s, falling back to log", email)
            print(f"[FALLBACK] Verification code for {email}: {code}")
    else:
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
            'user_id': int(user_id),
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
        'user_id': int(user_id),
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
