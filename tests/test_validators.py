"""Tests for utils/validators.py — no mocking needed, pure logic."""

import datetime

from OrbitServer.utils.validators import (
    validate_edu_email,
    validate_profile_data,
    validate_mission_data,
    validate_message_data,
    validate_vote_data,
)

# A date guaranteed to fall inside the today…+14-day scheduling window.
IN_WINDOW_DATE = (datetime.date.today() + datetime.timedelta(days=3)).isoformat()


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
            "college_year": "junior",
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

    def test_rejects_invalid_college_year(self):
        valid, errors = validate_profile_data({"college_year": "tenth_grade"})
        assert valid is False

    def test_accepts_valid_college_years(self):
        for year in ("freshman", "sophomore", "junior", "senior", "grad"):
            valid, errors = validate_profile_data({"college_year": year})
            assert valid is True, f"Expected {year} to be valid"

    def test_rejects_non_list_interests(self):
        valid, errors = validate_profile_data({"interests": "not a list"})
        assert valid is False

    def test_rejects_too_few_interests(self):
        valid, errors = validate_profile_data({"interests": ["a", "b"]})
        assert valid is False

    def test_rejects_too_many_interests(self):
        valid, errors = validate_profile_data({"interests": ["a"] * 11})
        assert valid is False

    def test_accepts_photo_url(self):
        valid, errors = validate_profile_data({"photo": "https://example.com/photo.jpg"})
        assert valid is True

    def test_accepts_null_photo(self):
        valid, errors = validate_profile_data({"photo": None})
        assert valid is True

    def test_rejects_non_string_photo(self):
        valid, errors = validate_profile_data({"photo": 12345})
        assert valid is False

    def test_rejects_old_fields(self):
        """Fields from the old profile schema should be rejected."""
        for field in ("age", "photos", "location", "personality"):
            valid, errors = validate_profile_data({field: "whatever"})
            assert valid is False, f"Expected old field '{field}' to be rejected"

    def test_collects_multiple_errors(self):
        data = {"name": "", "college_year": "invalid", "interests": ["only_one"]}
        valid, errors = validate_profile_data(data)
        assert valid is False
        assert len(errors) >= 2

    # ── Bio ──

    def test_accepts_valid_bio(self):
        valid, errors = validate_profile_data({"bio": "Hello, I love hiking!"})
        assert valid is True

    def test_accepts_empty_bio(self):
        valid, errors = validate_profile_data({"bio": ""})
        assert valid is True

    def test_rejects_long_bio(self):
        valid, errors = validate_profile_data({"bio": "x" * 251})
        assert valid is False
        assert any("250" in e for e in errors)

    def test_rejects_non_string_bio(self):
        valid, errors = validate_profile_data({"bio": 123})
        assert valid is False

    # ── Gallery Photos ──

    def test_accepts_valid_gallery_photos(self):
        valid, errors = validate_profile_data({
            "gallery_photos": ["https://example.com/1.jpg", "https://example.com/2.jpg"]
        })
        assert valid is True

    def test_accepts_empty_gallery(self):
        valid, errors = validate_profile_data({"gallery_photos": []})
        assert valid is True

    def test_rejects_too_many_gallery_photos(self):
        valid, errors = validate_profile_data({
            "gallery_photos": [f"https://example.com/{i}.jpg" for i in range(7)]
        })
        assert valid is False
        assert any("6" in e for e in errors)

    def test_rejects_non_list_gallery(self):
        valid, errors = validate_profile_data({"gallery_photos": "not a list"})
        assert valid is False

    def test_rejects_non_string_gallery_item(self):
        valid, errors = validate_profile_data({"gallery_photos": [123]})
        assert valid is False

    # ── Links ──

    def test_accepts_valid_links(self):
        valid, errors = validate_profile_data({
            "links": ["https://github.com/user", "https://linkedin.com/in/user"]
        })
        assert valid is True

    def test_rejects_too_many_links(self):
        valid, errors = validate_profile_data({
            "links": ["https://a.com", "https://b.com", "https://c.com", "https://d.com"]
        })
        assert valid is False
        assert any("3" in e for e in errors)

    def test_rejects_non_list_links(self):
        valid, errors = validate_profile_data({"links": "not a list"})
        assert valid is False

    def test_rejects_long_link(self):
        valid, errors = validate_profile_data({"links": ["x" * 501]})
        assert valid is False

    # ── Gender ──

    def test_accepts_valid_genders(self):
        for gender in ("male", "female", "non-binary", "other", ""):
            valid, errors = validate_profile_data({"gender": gender})
            assert valid is True, f"Expected '{gender}' to be valid"

    def test_rejects_invalid_gender(self):
        valid, errors = validate_profile_data({"gender": "alien"})
        assert valid is False

    # ── MBTI ──

    def test_accepts_valid_mbti(self):
        for mbti in ("INTJ", "ENFP", "ISTP", "ESFJ", ""):
            valid, errors = validate_profile_data({"mbti": mbti})
            assert valid is True, f"Expected '{mbti}' to be valid"

    def test_rejects_invalid_mbti(self):
        valid, errors = validate_profile_data({"mbti": "XXXX"})
        assert valid is False

    def test_accepts_all_new_fields_together(self):
        data = {
            "bio": "I love coffee",
            "gallery_photos": ["https://example.com/1.jpg"],
            "links": ["https://github.com/me"],
            "gender": "female",
            "mbti": "ENFP",
        }
        valid, errors = validate_profile_data(data)
        assert valid is True


# ── Mission Validation ────────────────────────────────────────────────────────

class TestValidateMissionData:
    def test_valid_event(self):
        valid, errors = validate_mission_data({
            "title": "Hike", "description": "Trail run",
            "date": IN_WINDOW_DATE, "start_time": "14:00", "end_time": "16:00"
        })
        assert valid is True

    def test_rejects_missing_title(self):
        valid, errors = validate_mission_data({"description": "Fun"})
        assert valid is False

    def test_accepts_missing_description(self):
        valid, errors = validate_mission_data({
            "title": "Hike", "date": IN_WINDOW_DATE,
            "start_time": "14:00", "end_time": "16:00"
        })
        assert valid is True

    def test_rejects_long_title(self):
        valid, errors = validate_mission_data({"title": "x" * 201, "description": "Fun"})
        assert valid is False

    def test_rejects_long_description(self):
        valid, errors = validate_mission_data({"title": "Hike", "description": "x" * 2001})
        assert valid is False

    def test_rejects_too_many_tags(self):
        valid, errors = validate_mission_data({
            "title": "Hike", "description": "Fun",
            "tags": ["tag"] * 11
        })
        assert valid is False

    def test_rejects_non_list_tags(self):
        valid, errors = validate_mission_data({
            "title": "Hike", "description": "Fun", "tags": "not a list"
        })
        assert valid is False

    def test_rejects_invalid_pod_size(self):
        valid, errors = validate_mission_data({
            "title": "Hike", "description": "Fun", "max_pod_size": 1
        })
        assert valid is False

    def test_accepts_valid_pod_size(self):
        valid, errors = validate_mission_data({
            "title": "Hike", "description": "Fun", "max_pod_size": 4,
            "date": IN_WINDOW_DATE, "start_time": "14:00", "end_time": "16:00"
        })
        assert valid is True

    def test_rejects_bad_date_format(self):
        valid, errors = validate_mission_data({
            "title": "Hike", "description": "Fun", "date": "not-a-date"
        })
        assert valid is False

    def test_accepts_valid_date(self):
        valid, errors = validate_mission_data({
            "title": "Hike", "description": "Fun", "date": IN_WINDOW_DATE,
            "start_time": "14:00", "end_time": "16:00"
        })
        assert valid is True

    def test_set_accepts_without_end_time(self):
        # Single-day mission with a start time but no end time is valid.
        valid, errors = validate_mission_data({
            "title": "Hike", "date": IN_WINDOW_DATE, "start_time": "14:00",
        })
        assert valid is True

    def test_set_still_requires_start_time(self):
        valid, errors = validate_mission_data({
            "title": "Hike", "date": IN_WINDOW_DATE,
        })
        assert valid is False

    def test_update_mode_skips_required_fields(self):
        valid, errors = validate_mission_data({"title": "Updated"}, is_update=True)
        assert valid is True

    # ── Scheduling window (today … +14 days) ────────────────────────────────

    def test_rejects_set_date_too_far_out(self):
        far = (datetime.date.today() + datetime.timedelta(days=30)).isoformat()
        valid, errors = validate_mission_data({
            "title": "Hike", "date": far, "start_time": "14:00", "end_time": "16:00"
        })
        assert valid is False

    def test_rejects_set_date_in_past(self):
        past = (datetime.date.today() - datetime.timedelta(days=2)).isoformat()
        valid, errors = validate_mission_data({
            "title": "Hike", "date": past, "start_time": "14:00", "end_time": "16:00"
        })
        assert valid is False

    # ── Pod size bounds ─────────────────────────────────────────────────────

    def test_rejects_min_greater_than_max(self):
        valid, errors = validate_mission_data({
            "title": "Hike", "date": IN_WINDOW_DATE,
            "start_time": "14:00", "end_time": "16:00",
            "min_pod_size": 6, "max_pod_size": 4,
        })
        assert valid is False

    def test_rejects_pod_size_below_three(self):
        # A pod of two could leave two strangers alone — minimum is three.
        valid, errors = validate_mission_data({
            "title": "Hike", "date": IN_WINDOW_DATE, "start_time": "14:00",
            "min_pod_size": 2, "max_pod_size": 4,
        })
        assert valid is False

    # ── Images ──────────────────────────────────────────────────────────────

    def test_rejects_too_many_images(self):
        valid, errors = validate_mission_data({
            "title": "Hike", "date": IN_WINDOW_DATE,
            "start_time": "14:00", "end_time": "16:00",
            "images": ["a", "b", "c", "d"],
        })
        assert valid is False

    # ── Flex mode ───────────────────────────────────────────────────────────

    def test_accepts_valid_flex_mission(self):
        valid, errors = validate_mission_data({
            "mode": "flex", "title": "Pickup ball", "description": "Fun",
            "min_pod_size": 3, "max_pod_size": 8,
            "availability": [{"date": IN_WINDOW_DATE, "hours": [14, 15]}],
            "scheduling_window_days": 7,
        })
        assert valid is True

    def test_rejects_flex_without_availability(self):
        valid, errors = validate_mission_data({
            "mode": "flex", "title": "Pickup ball", "availability": [],
        })
        assert valid is False

    def test_rejects_flex_window_out_of_range(self):
        valid, errors = validate_mission_data({
            "mode": "flex", "title": "Pickup ball",
            "availability": [{"date": IN_WINDOW_DATE, "hours": [14]}],
            "scheduling_window_days": 30,
        })
        assert valid is False


# ── Message Validation ───────────────────────────────────────────────────────

class TestValidateMessageData:
    def test_valid_message(self):
        valid, errors = validate_message_data({"content": "Hello everyone!"})
        assert valid is True

    def test_rejects_missing_content(self):
        valid, errors = validate_message_data({})
        assert valid is False

    def test_rejects_empty_content(self):
        valid, errors = validate_message_data({"content": "   "})
        assert valid is False

    def test_rejects_long_content(self):
        valid, errors = validate_message_data({"content": "x" * 1001})
        assert valid is False

    def test_rejects_non_string_content(self):
        valid, errors = validate_message_data({"content": 12345})
        assert valid is False


# ── Vote Validation ──────────────────────────────────────────────────────────

class TestValidateVoteData:
    def test_valid_time_vote(self):
        valid, errors = validate_vote_data({
            "vote_type": "time",
            "options": ["Saturday 2pm", "Sunday 3pm"]
        })
        assert valid is True

    def test_valid_place_vote(self):
        valid, errors = validate_vote_data({
            "vote_type": "place",
            "options": ["Library", "Coffee Shop", "Park"]
        })
        assert valid is True

    def test_rejects_invalid_vote_type(self):
        valid, errors = validate_vote_data({
            "vote_type": "date",
            "options": ["Monday", "Tuesday"]
        })
        assert valid is False

    def test_rejects_missing_vote_type(self):
        valid, errors = validate_vote_data({"options": ["A", "B"]})
        assert valid is False

    def test_rejects_too_few_options(self):
        valid, errors = validate_vote_data({"vote_type": "time", "options": ["only one"]})
        assert valid is False

    def test_rejects_too_many_options(self):
        valid, errors = validate_vote_data({
            "vote_type": "time",
            "options": ["a", "b", "c", "d", "e"]  # max is 4
        })
        assert valid is False

    def test_rejects_non_list_options(self):
        valid, errors = validate_vote_data({"vote_type": "time", "options": "not a list"})
        assert valid is False


class TestValidateMissionLinks:
    """Links are optional on both set and flex missions (max 3)."""

    def _set_mission(self, **overrides):
        data = {
            'title': 'BBQ Night',
            'mode': 'set',
            'date': datetime.date.today().isoformat(),
            'start_time': '18:00',
        }
        data.update(overrides)
        return data

    def test_set_mission_accepts_links(self):
        valid, errors = validate_mission_data(
            self._set_mission(links=['https://example.com/menu']))
        assert valid, errors

    def test_accepts_up_to_three_links(self):
        valid, errors = validate_mission_data(
            self._set_mission(links=['https://a.com', 'https://b.com', 'https://c.com']))
        assert valid, errors

    def test_rejects_four_links(self):
        valid, errors = validate_mission_data(
            self._set_mission(links=['a', 'b', 'c', 'd']))
        assert not valid
        assert any('Maximum 3 links' in e for e in errors)

    def test_rejects_non_list_links(self):
        valid, errors = validate_mission_data(self._set_mission(links='https://a.com'))
        assert not valid
        assert any('links must be a list' in e for e in errors)

    def test_rejects_non_string_link(self):
        valid, errors = validate_mission_data(self._set_mission(links=[123]))
        assert not valid

    def test_rejects_overlong_link(self):
        valid, errors = validate_mission_data(self._set_mission(links=['x' * 501]))
        assert not valid
