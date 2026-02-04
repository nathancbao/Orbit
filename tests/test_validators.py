"""Tests for utils/validators.py — no mocking needed, pure logic."""

from OrbitServer.utils.validators import validate_edu_email, validate_profile_data, validate_crew_data, validate_mission_data


# ── Email Validation ────────────────────────────────────────────────────────

class TestValidateEduEmail:
    def test_valid_edu_email(self):
        valid, result = validate_edu_email("student@university.edu")
        assert valid is True
        assert result == "student@university.edu"

    def test_valid_edu_email_with_caps(self):
        valid, result = validate_edu_email("Student@University.EDU")
        assert valid is True
        assert result == "student@university.edu"

    def test_valid_edu_email_with_whitespace(self):
        valid, result = validate_edu_email("  student@university.edu  ")
        assert valid is True
        assert result == "student@university.edu"

    def test_rejects_non_edu_email(self):
        valid, result = validate_edu_email("user@gmail.com")
        assert valid is False
        assert "edu" in result.lower()

    def test_rejects_empty_email(self):
        valid, result = validate_edu_email("")
        assert valid is False

    def test_rejects_none_email(self):
        valid, result = validate_edu_email(None)
        assert valid is False

    def test_rejects_invalid_format(self):
        valid, result = validate_edu_email("not-an-email")
        assert valid is False

    def test_rejects_missing_domain(self):
        valid, result = validate_edu_email("user@.edu")
        assert valid is False


# ── Profile Validation ──────────────────────────────────────────────────────

class TestValidateProfileData:
    def test_valid_profile(self):
        data = {
            "name": "Test User",
            "age": 21,
            "bio": "Hello",
            "interests": ["coding", "music", "hiking"],
        }
        valid, errors = validate_profile_data(data)
        assert valid is True
        assert errors is None

    def test_empty_data_is_valid(self):
        valid, errors = validate_profile_data({})
        assert valid is True

    def test_rejects_unknown_field(self):
        valid, errors = validate_profile_data({"unknown_field": "value"})
        assert valid is False
        assert any("Unknown field" in e for e in errors)

    def test_rejects_empty_name(self):
        valid, errors = validate_profile_data({"name": ""})
        assert valid is False

    def test_rejects_long_name(self):
        valid, errors = validate_profile_data({"name": "a" * 101})
        assert valid is False

    def test_rejects_age_below_18(self):
        valid, errors = validate_profile_data({"age": 17})
        assert valid is False

    def test_rejects_age_above_100(self):
        valid, errors = validate_profile_data({"age": 101})
        assert valid is False

    def test_accepts_age_18(self):
        valid, errors = validate_profile_data({"age": 18})
        assert valid is True

    def test_rejects_long_bio(self):
        valid, errors = validate_profile_data({"bio": "x" * 501})
        assert valid is False

    def test_rejects_too_many_interests(self):
        valid, errors = validate_profile_data({"interests": ["a"] * 11})
        assert valid is False

    def test_rejects_too_many_photos(self):
        valid, errors = validate_profile_data({"photos": ["url"] * 7})
        assert valid is False

    def test_rejects_non_list_interests(self):
        valid, errors = validate_profile_data({"interests": "not a list"})
        assert valid is False

    def test_rejects_non_dict_location(self):
        valid, errors = validate_profile_data({"location": "not a dict"})
        assert valid is False

    def test_rejects_non_dict_personality(self):
        valid, errors = validate_profile_data({"personality": "not a dict"})
        assert valid is False

    def test_collects_multiple_errors(self):
        data = {"name": "", "age": 5, "bio": "x" * 501}
        valid, errors = validate_profile_data(data)
        assert valid is False
        assert len(errors) == 3


# ── Crew Validation ─────────────────────────────────────────────────────────

class TestValidateCrewData:
    def test_valid_crew(self):
        valid, errors = validate_crew_data({"name": "Study Group"})
        assert valid is True

    def test_rejects_missing_name(self):
        valid, errors = validate_crew_data({})
        assert valid is False

    def test_rejects_empty_name(self):
        valid, errors = validate_crew_data({"name": ""})
        assert valid is False

    def test_rejects_long_name(self):
        valid, errors = validate_crew_data({"name": "a" * 101})
        assert valid is False

    def test_rejects_long_description(self):
        valid, errors = validate_crew_data({"name": "ok", "description": "x" * 501})
        assert valid is False


# ── Mission Validation ──────────────────────────────────────────────────────

class TestValidateMissionData:
    def test_valid_mission(self):
        valid, errors = validate_mission_data({"title": "Hike", "description": "Let's go hiking"})
        assert valid is True

    def test_rejects_missing_title(self):
        valid, errors = validate_mission_data({"description": "something"})
        assert valid is False

    def test_rejects_missing_description(self):
        valid, errors = validate_mission_data({"title": "something"})
        assert valid is False

    def test_rejects_long_title(self):
        valid, errors = validate_mission_data({"title": "a" * 201, "description": "ok"})
        assert valid is False
