"""Tests for services/user_service.py — pure business logic, no mocking needed."""

from OrbitServer.services.user_service import _format_profile, _is_profile_complete, DEFAULT_PROFILE


# ── _format_profile ─────────────────────────────────────────────────────────

class TestFormatProfile:
    def test_extracts_known_fields(self):
        raw = {"name": "Ada", "college_year": "junior", "interests": ["hiking"], "extra_field": "ignored"}
        result = _format_profile(raw)
        assert result["name"] == "Ada"
        assert result["college_year"] == "junior"
        assert result["interests"] == ["hiking"]
        assert "extra_field" not in result

    def test_fills_missing_fields_with_defaults(self):
        raw = {"name": "Ada"}
        result = _format_profile(raw)
        assert result["name"] == "Ada"
        assert result["interests"] == []
        assert result["trust_score"] == DEFAULT_PROFILE["trust_score"]
        assert result["photo"] is None

    def test_empty_input_returns_all_defaults(self):
        result = _format_profile({})
        for field in DEFAULT_PROFILE:
            assert result[field] == DEFAULT_PROFILE[field]

    def test_preserves_interests_list(self):
        raw = {"name": "Ada", "interests": ["hiking", "coffee", "gaming"]}
        result = _format_profile(raw)
        assert result["interests"] == ["hiking", "coffee", "gaming"]

    def test_output_has_exactly_profile_fields(self):
        from OrbitServer.services.user_service import PROFILE_FIELDS
        result = _format_profile({"name": "Test"})
        assert set(result.keys()) == set(PROFILE_FIELDS)

    def test_preserves_photo_url(self):
        raw = {"name": "Ada", "photo": "https://example.com/photo.jpg"}
        result = _format_profile(raw)
        assert result["photo"] == "https://example.com/photo.jpg"

    def test_preserves_trust_score(self):
        raw = {"name": "Ada", "trust_score": 4.2}
        result = _format_profile(raw)
        assert result["trust_score"] == 4.2


# ── _is_profile_complete ────────────────────────────────────────────────────

class TestIsProfileComplete:
    def test_complete_profile(self):
        profile = {
            "name": "Ada",
            "college_year": "junior",
            "interests": ["hiking", "coffee", "gaming"],
        }
        assert _is_profile_complete(profile) is True

    def test_incomplete_missing_name(self):
        profile = {
            "name": "",
            "college_year": "junior",
            "interests": ["a", "b", "c"],
        }
        assert _is_profile_complete(profile) is False

    def test_incomplete_no_name_key(self):
        profile = {
            "college_year": "junior",
            "interests": ["a", "b", "c"],
        }
        assert _is_profile_complete(profile) is False

    def test_incomplete_missing_college_year(self):
        profile = {
            "name": "Ada",
            "interests": ["a", "b", "c"],
        }
        assert _is_profile_complete(profile) is False

    def test_incomplete_empty_college_year(self):
        profile = {
            "name": "Ada",
            "college_year": "",
            "interests": ["a", "b", "c"],
        }
        assert _is_profile_complete(profile) is False

    def test_incomplete_too_few_interests(self):
        profile = {
            "name": "Ada",
            "college_year": "sophomore",
            "interests": ["a", "b"],  # needs 3
        }
        assert _is_profile_complete(profile) is False

    def test_incomplete_no_interests(self):
        profile = {
            "name": "Ada",
            "college_year": "freshman",
        }
        assert _is_profile_complete(profile) is False

    def test_whitespace_only_name_is_incomplete(self):
        profile = {
            "name": "   ",
            "college_year": "junior",
            "interests": ["a", "b", "c"],
        }
        assert _is_profile_complete(profile) is False

    def test_non_string_name_is_incomplete(self):
        profile = {
            "name": 123,
            "college_year": "junior",
            "interests": ["a", "b", "c"],
        }
        assert _is_profile_complete(profile) is False

    def test_exactly_three_interests_is_complete(self):
        profile = {
            "name": "Ada",
            "college_year": "grad",
            "interests": ["a", "b", "c"],
        }
        assert _is_profile_complete(profile) is True

    def test_more_than_three_interests_is_complete(self):
        profile = {
            "name": "Ada",
            "college_year": "senior",
            "interests": ["a", "b", "c", "d", "e"],
        }
        assert _is_profile_complete(profile) is True
