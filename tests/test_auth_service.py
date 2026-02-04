"""Tests for services/auth_service.py — verify_code and refresh logic."""

import datetime
from unittest.mock import patch, MagicMock
from OrbitServer.utils.auth import create_access_token, create_refresh_token


class TestVerifyCodeDemoBypass:
    """The demo bypass accepts code '123456' for any email."""

    @patch('OrbitServer.services.auth_service.store_refresh_token')
    @patch('OrbitServer.services.auth_service.create_user')
    @patch('OrbitServer.services.auth_service.get_user_by_email')
    def test_creates_new_user(self, mock_get, mock_create, mock_store):
        from OrbitServer.services.auth_service import verify_code
        mock_get.return_value = None
        mock_create.return_value = {'id': 1, 'email': 'a@b.edu'}

        result, err = verify_code('a@b.edu', '123456')
        assert err is None
        assert result['is_new_user'] is True
        assert 'access_token' in result
        assert 'refresh_token' in result
        assert result['expires_in'] == 900
        mock_create.assert_called_once_with('a@b.edu')

    @patch('OrbitServer.services.auth_service.store_refresh_token')
    @patch('OrbitServer.services.auth_service.get_user_by_email')
    def test_returns_existing_user(self, mock_get, mock_store):
        from OrbitServer.services.auth_service import verify_code
        mock_get.return_value = {'id': 5, 'email': 'a@b.edu'}

        result, err = verify_code('a@b.edu', '123456')
        assert err is None
        assert result['is_new_user'] is False
        assert result['user_id'] == 5

    @patch('OrbitServer.services.auth_service.store_refresh_token')
    @patch('OrbitServer.services.auth_service.get_user_by_email')
    def test_bypass_with_whitespace(self, mock_get, mock_store):
        from OrbitServer.services.auth_service import verify_code
        mock_get.return_value = {'id': 1, 'email': 'a@b.edu'}

        result, err = verify_code('a@b.edu', ' 123456 ')
        assert err is None  # strips whitespace


class TestVerifyCodeNormal:
    """Normal (non-demo) code verification flow."""

    @patch('OrbitServer.services.auth_service.get_verification_code')
    def test_no_code_stored(self, mock_get_code):
        from OrbitServer.services.auth_service import verify_code
        mock_get_code.return_value = None

        result, err = verify_code('a@b.edu', '999999')
        assert result is None
        assert "No verification code found" in err

    @patch('OrbitServer.services.auth_service.delete_verification_code')
    @patch('OrbitServer.services.auth_service.get_verification_code')
    def test_expired_code(self, mock_get_code, mock_delete):
        from OrbitServer.services.auth_service import verify_code
        mock_get_code.return_value = {
            'code': '999999',
            'expires_at': datetime.datetime.utcnow() - datetime.timedelta(minutes=1),
        }

        result, err = verify_code('a@b.edu', '999999')
        assert result is None
        assert "expired" in err.lower()
        mock_delete.assert_called_once()

    @patch('OrbitServer.services.auth_service.get_verification_code')
    def test_wrong_code(self, mock_get_code):
        from OrbitServer.services.auth_service import verify_code
        mock_get_code.return_value = {
            'code': '111111',
            'expires_at': datetime.datetime.utcnow() + datetime.timedelta(minutes=5),
        }

        result, err = verify_code('a@b.edu', '999999')
        assert result is None
        assert "Invalid" in err

    @patch('OrbitServer.services.auth_service.store_refresh_token')
    @patch('OrbitServer.services.auth_service.create_user')
    @patch('OrbitServer.services.auth_service.get_user_by_email')
    @patch('OrbitServer.services.auth_service.delete_verification_code')
    @patch('OrbitServer.services.auth_service.get_verification_code')
    def test_correct_code_new_user(self, mock_get_code, mock_delete_code,
                                    mock_get_user, mock_create, mock_store_rt):
        from OrbitServer.services.auth_service import verify_code
        mock_get_code.return_value = {
            'code': '555555',
            'expires_at': datetime.datetime.utcnow() + datetime.timedelta(minutes=5),
        }
        mock_get_user.return_value = None
        mock_create.return_value = {'id': 10, 'email': 'a@b.edu'}

        result, err = verify_code('a@b.edu', '555555')
        assert err is None
        assert result['is_new_user'] is True
        assert result['user_id'] == 10
        mock_delete_code.assert_called_once()


class TestRefreshAccessToken:
    @patch('OrbitServer.services.auth_service.get_refresh_token')
    def test_invalid_token_not_in_store(self, mock_get):
        from OrbitServer.services.auth_service import refresh_access_token
        mock_get.return_value = None

        result, err = refresh_access_token('bad-token')
        assert result is None
        assert "Invalid" in err

    @patch('OrbitServer.services.auth_service.create_access_token')
    @patch('OrbitServer.services.auth_service.get_refresh_token')
    def test_valid_refresh_returns_new_access(self, mock_get, mock_create_at):
        from OrbitServer.services.auth_service import refresh_access_token
        # Create a real refresh token so decode_token succeeds
        real_token = create_refresh_token(42)
        mock_get.return_value = {'user_id': 42}
        mock_create_at.return_value = 'new-access-token'

        result, err = refresh_access_token(real_token)
        assert err is None
        assert result['access_token'] == 'new-access-token'
        mock_create_at.assert_called_once_with(42)

    @patch('OrbitServer.services.auth_service.delete_refresh_token')
    @patch('OrbitServer.services.auth_service.get_refresh_token')
    def test_expired_refresh_deletes_and_errors(self, mock_get, mock_delete):
        from OrbitServer.services.auth_service import refresh_access_token
        mock_get.return_value = {'user_id': 1}

        result, err = refresh_access_token('not.a.valid.jwt')
        assert result is None
        assert err is not None
        mock_delete.assert_called_once()

    @patch('OrbitServer.services.auth_service.get_refresh_token')
    def test_access_token_rejected_as_refresh(self, mock_get):
        """An access token should be rejected even if it decodes fine."""
        from OrbitServer.services.auth_service import refresh_access_token
        access_token = create_access_token(1)
        mock_get.return_value = {'user_id': 1}

        result, err = refresh_access_token(access_token)
        assert result is None
        assert "Invalid token type" in err


class TestLogout:
    @patch('OrbitServer.services.auth_service.delete_refresh_token')
    def test_deletes_token(self, mock_delete):
        from OrbitServer.services.auth_service import logout
        result = logout('some-token')
        assert result is True
        mock_delete.assert_called_once_with('some-token')
