import os
import random
import datetime

from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail

from models.models import (
    get_user_by_email, create_user,
    store_verification_code, get_verification_code, delete_verification_code,
    store_refresh_token, get_refresh_token, delete_refresh_token,
)
from utils.auth import create_access_token, create_refresh_token, decode_token

SENDGRID_API_KEY = os.environ.get('SENDGRID_API_KEY', '')
FROM_EMAIL = os.environ.get('FROM_EMAIL', 'noreply@orbitapp.com')


def send_verification_code(email):
    code = str(random.randint(100000, 999999))
    store_verification_code(email, code)

    print(f"[DEBUG] Sending verification code {code} to {email}")
    print(f"[DEBUG] FROM_EMAIL: {FROM_EMAIL}")
    print(f"[DEBUG] API Key present: {bool(SENDGRID_API_KEY)}")

    message = Mail(
        from_email=FROM_EMAIL,
        to_emails=email,
        subject='Orbit - Your Verification Code',
        plain_text_content=f'Your Orbit verification code is: {code}\n\nThis code expires in 10 minutes.',
    )
    sg = SendGridAPIClient(SENDGRID_API_KEY)
    response = sg.send(message)

    print(f"[DEBUG] SendGrid response status: {response.status_code}")
    print(f"[DEBUG] SendGrid response body: {response.body}")
    print(f"[DEBUG] SendGrid response headers: {response.headers}")

    return True    




def verify_code(email, code):
    record = get_verification_code(email)
    if not record:
        return None, "No verification code found for this email"

    # Fix datetime comparison
    expires_at = record['expires_at']
    if hasattr(expires_at, 'tzinfo') and expires_at.tzinfo:
        now = datetime.datetime.now(datetime.timezone.utc)
    else:
        now = datetime.datetime.utcnow()

    if now > expires_at:
        delete_verification_code(email)
        return None, "Verification code has expired"

    if record['code'] != code:
        return None, "Invalid verification code"

    delete_verification_code(email)

    user = get_user_by_email(email)
    is_new_user = user is None
    if is_new_user:
        user = create_user(email)

    user_id = user['id']
    access_token = create_access_token(user_id)
    refresh_token = create_refresh_token(user_id)
    store_refresh_token(refresh_token, user_id)

    return {
        'access_token': access_token,
        'refresh_token': refresh_token,
        'expires_in': 900,
        'is_new_user': is_new_user,
        'user_id': user_id,
    }, None     


def refresh_access_token(refresh_token):
    record = get_refresh_token(refresh_token)
    if not record:
        return None, "Invalid refresh token"

    payload, err = decode_token(refresh_token)
    if err:
        delete_refresh_token(refresh_token)
        return None, err

    if payload.get('type') != 'refresh':
        return None, "Invalid token type"

    user_id = payload['user_id']
    new_access_token = create_access_token(user_id)

    return {'access_token': new_access_token}, None


def logout(refresh_token):
    delete_refresh_token(refresh_token)
    return True
