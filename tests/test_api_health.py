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
