"""Tests for top-level routes in main.py."""

import json


class TestHealthEndpoints:
    def test_home(self, client):
        resp = client.get('/')
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert "status" in body

    def test_health(self, client):
        resp = client.get('/api/health')
        body = json.loads(resp.data)
        assert resp.status_code == 200
        assert body["status"] == "healthy"


class TestSecurityHeaders:
    def test_headers_present(self, client):
        resp = client.get('/api/health')
        assert resp.headers['X-Content-Type-Options'] == 'nosniff'
        assert resp.headers['X-Frame-Options'] == 'DENY'
        assert resp.headers['Referrer-Policy'] == 'no-referrer'
        assert 'max-age=' in resp.headers['Strict-Transport-Security']


class TestErrorEnvelope:
    def test_unknown_route_returns_json_404(self, client):
        resp = client.get('/api/does-not-exist')
        assert resp.status_code == 404
        body = json.loads(resp.data)
        # HTTP errors come back in the same envelope as everything else, not HTML.
        assert body["success"] is False
        assert "error" in body

    def test_method_not_allowed_returns_json(self, client):
        resp = client.delete('/api/health')
        assert resp.status_code == 405
        body = json.loads(resp.data)
        assert body["success"] is False
