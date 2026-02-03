"""Tests for utils/responses.py — uses Flask test request context."""

import json
from utils.responses import success, error


class TestSuccessResponse:
    def test_success_with_data(self, app):
        with app.app_context():
            resp, status = success({"key": "value"})
            body = json.loads(resp.data)
            assert status == 200
            assert body["success"] is True
            assert body["data"]["key"] == "value"

    def test_success_without_data(self, app):
        with app.app_context():
            resp, status = success()
            body = json.loads(resp.data)
            assert status == 200
            assert body["success"] is True
            assert "data" not in body

    def test_success_custom_status(self, app):
        with app.app_context():
            resp, status = success({"id": 1}, status=201)
            assert status == 201


class TestErrorResponse:
    def test_error_default_400(self, app):
        with app.app_context():
            resp, status = error("Something went wrong")
            body = json.loads(resp.data)
            assert status == 400
            assert body["success"] is False
            assert body["error"] == "Something went wrong"

    def test_error_custom_status(self, app):
        with app.app_context():
            resp, status = error("Not found", 404)
            assert status == 404

    def test_error_401(self, app):
        with app.app_context():
            resp, status = error("Unauthorized", 401)
            body = json.loads(resp.data)
            assert status == 401
            assert body["success"] is False
