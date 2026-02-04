"""Tests for utils/auth.py — JWT token creation and decoding."""

import os
import time
import datetime

# Ensure test secret is set before importing
os.environ['JWT_SECRET'] = 'test-secret-key'

from OrbitServer.utils.auth import create_access_token, create_refresh_token, decode_token


class TestCreateAccessToken:
    def test_returns_string(self):
        token = create_access_token(123)
        assert isinstance(token, str)
        assert len(token) > 0

    def test_contains_correct_claims(self):
        token = create_access_token(42)
        payload, err = decode_token(token)
        assert err is None
        assert payload['user_id'] == 42
        assert payload['type'] == 'access'

    def test_has_expiration(self):
        token = create_access_token(1)
        payload, _ = decode_token(token)
        assert 'exp' in payload
        assert 'iat' in payload


class TestCreateRefreshToken:
    def test_returns_string(self):
        token = create_refresh_token(123)
        assert isinstance(token, str)
        assert len(token) > 0

    def test_contains_correct_claims(self):
        token = create_refresh_token(42)
        payload, err = decode_token(token)
        assert err is None
        assert payload['user_id'] == 42
        assert payload['type'] == 'refresh'

    def test_different_from_access_token(self):
        access = create_access_token(1)
        refresh = create_refresh_token(1)
        assert access != refresh


class TestDecodeToken:
    def test_decode_valid_token(self):
        token = create_access_token(99)
        payload, err = decode_token(token)
        assert err is None
        assert payload['user_id'] == 99

    def test_decode_invalid_token(self):
        payload, err = decode_token("not.a.real.token")
        assert payload is None
        assert err is not None
        assert "Invalid" in err

    def test_decode_empty_string(self):
        payload, err = decode_token("")
        assert payload is None
        assert err is not None

    def test_decode_tampered_token(self):
        token = create_access_token(1)
        tampered = token[:-5] + "XXXXX"
        payload, err = decode_token(tampered)
        assert payload is None
        assert err is not None
