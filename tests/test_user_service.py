"""Tests for services/user_service.py — pure business logic, no mocking needed."""

from services.user_service import _format_profile, _is_profile_complete, DEFAULT_PROFILE


# ── _format_profile ─────────────────────────────────────────────────────────

class TestFormatProfile:
    def test_extracts_known_fields(self):
        raw = {"name": "Ada", "age": 21, "bio": "Hi", "extra_field": "ignored"}
        result = _format_profile(raw)
        assert result["name"] == "Ada"
        assert result["age"] == 21
        assert result["bio"] == "Hi"
        assert "extra_field" not in result

    def test_fills_missing_fields_with_defaults(self):
        raw = {"name": "Ada"}
        result = _format_profile(raw)
        assert result["name"] == "Ada"
        assert result["age"] == DEFAULT_PROFILE["age"]
        assert result["interests"] == []
        assert result["photos"] == []
        assert result["personality"] == DEFAULT_PROFILE["personality"]

    def test_empty_input_returns_all_defaults(self):
        result = _format_profile({})
        for field in DEFAULT_PROFILE:
            assert result[field] == DEFAULT_PROFILE[field]

    def test_preserves_nested_structures(self):
        raw = {
            "name": "Ada",
            "location": {"city": "LA", "state": "CA", "coordinates": None},
            "personality": {
                "introvert_extrovert": 0.8,
                "spontaneous_planner": 0.2,
                "active_relaxed": 0.6,
            },
        }
        result = _format_profile(raw)
        assert result["location"]["city"] == "LA"
        assert result["personality"]["introvert_extrovert"] == 0.8

    def test_output_has_exactly_profile_fields(self):
        from services.user_service import PROFILE_FIELDS
        result = _format_profile({"name": "Test"})
        assert set(result.keys()) == set(PROFILE_FIELDS)


# ── _is_profile_complete ────────────────────────────────────────────────────

class TestIsProfileComplete:
    def test_complete_profile(self):
        profile = {
            "name": "Ada",
            "interests": ["a", "b", "c"],
            "social_preferences": {
                "group_size": "Small",
                "meeting_frequency": "Weekly",
                "preferred_times": ["Weekends"],
            },
        }
        assert _is_profile_complete(profile) is True

    def test_incomplete_missing_name(self):
        profile = {
            "name": "",
            "interests": ["a", "b", "c"],
            "social_preferences": {"preferred_times": ["Weekends"]},
        }
        assert _is_profile_complete(profile) is False

    def test_incomplete_no_name_key(self):
        profile = {
            "interests": ["a", "b", "c"],
            "social_preferences": {"preferred_times": ["Weekends"]},
        }
        assert _is_profile_complete(profile) is False

    def test_incomplete_too_few_interests(self):
        profile = {
            "name": "Ada",
            "interests": ["a", "b"],  # needs 3
            "social_preferences": {"preferred_times": ["Weekends"]},
        }
        assert _is_profile_complete(profile) is False

    def test_incomplete_no_interests(self):
        profile = {
            "name": "Ada",
            "social_preferences": {"preferred_times": ["Weekends"]},
        }
        assert _is_profile_complete(profile) is False

    def test_incomplete_no_preferred_times(self):
        profile = {
            "name": "Ada",
            "interests": ["a", "b", "c"],
            "social_preferences": {"preferred_times": []},
        }
        assert _is_profile_complete(profile) is False

    def test_incomplete_missing_social_prefs(self):
        profile = {
            "name": "Ada",
            "interests": ["a", "b", "c"],
        }
        assert _is_profile_complete(profile) is False

    def test_whitespace_only_name_is_incomplete(self):
        profile = {
            "name": "   ",
            "interests": ["a", "b", "c"],
            "social_preferences": {"preferred_times": ["Weekends"]},
        }
        assert _is_profile_complete(profile) is False

    def test_non_string_name_is_incomplete(self):
        profile = {
            "name": 123,
            "interests": ["a", "b", "c"],
            "social_preferences": {"preferred_times": ["Weekends"]},
        }
        assert _is_profile_complete(profile) is False

    def test_non_dict_social_prefs_is_incomplete(self):
        """If social_preferences is corrupted to a non-dict, should not crash."""
        profile = {
            "name": "Ada",
            "interests": ["a", "b", "c"],
            "social_preferences": "not a dict",
        }
        assert _is_profile_complete(profile) is False
