"""Tests for services/matching_service.py — AI matching logic (Jaccard similarity)."""

from unittest.mock import patch, MagicMock
from OrbitServer.services.matching_service import (
    _format_profile,
    suggested_users,
    suggested_crews,
    suggested_missions,
    PROFILE_FIELDS,
    DEFAULT_PROFILE,
)


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
        assert result["interests"] == []
        assert result["photos"] == []
        assert result["personality"] == DEFAULT_PROFILE["personality"]

    def test_empty_input_returns_all_defaults(self):
        result = _format_profile({})
        for field in PROFILE_FIELDS:
            assert result[field] == DEFAULT_PROFILE[field]

    def test_output_has_exactly_profile_fields(self):
        result = _format_profile({"name": "Test"})
        assert set(result.keys()) == set(PROFILE_FIELDS)

    def test_preserves_interests_list(self):
        raw = {"name": "Ada", "interests": ["hiking", "music", "gaming"]}
        result = _format_profile(raw)
        assert result["interests"] == ["hiking", "music", "gaming"]

    def test_preserves_nested_personality(self):
        raw = {
            "name": "Ada",
            "personality": {
                "introvert_extrovert": 0.9,
                "spontaneous_planner": 0.1,
                "active_relaxed": 0.7,
            },
        }
        result = _format_profile(raw)
        assert result["personality"]["introvert_extrovert"] == 0.9


# ── Helpers ──────────────────────────────────────────────────────────────────

def _make_entity(user_id, name, interests=None):
    """Create a mock Datastore entity dict (as _entity_to_dict would return)."""
    return {
        "user_id": user_id,
        "name": name,
        "interests": interests or [],
        "age": 20,
        "bio": "",
        "location": {"city": "", "state": "", "coordinates": None},
        "photos": [],
        "personality": {
            "introvert_extrovert": 0.5,
            "spontaneous_planner": 0.5,
            "active_relaxed": 0.5,
        },
        "social_preferences": {
            "group_size": "Small groups (3-5)",
            "meeting_frequency": "Weekly",
            "preferred_times": [],
        },
        "friendship_goals": [],
    }


def _mock_entity(data):
    """Wrap a dict to look like a Datastore Entity for _entity_to_dict mocking."""
    entity = MagicMock()
    entity.__iter__ = lambda self: iter(data)
    entity.items.return_value = data.items()
    entity.__getitem__ = lambda self, k: data[k]
    entity.get = data.get
    entity.key.id_or_name = data.get("user_id", 0)
    return entity


# ── suggested_users (Jaccard similarity) ─────────────────────────────────────

class TestSuggestedUsers:
    """Test the core Jaccard similarity matching for user suggestions."""

    @patch('OrbitServer.services.matching_service._entity_to_dict')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_perfect_match_identical_interests(self, mock_get_profile, mock_to_dict):
        """Two users with identical interests should score 1.0."""
        mock_get_profile.return_value = {"interests": ["hiking", "music", "gaming"]}

        other = _make_entity(2, "Bob", ["hiking", "music", "gaming"])
        entity = _mock_entity(other)
        mock_to_dict.return_value = other

        import google.cloud.datastore as ds
        mock_client = MagicMock()
        mock_query = MagicMock()
        mock_query.fetch.return_value = [entity]
        mock_client.query.return_value = mock_query

        with patch.object(ds, 'Client', return_value=mock_client):
            results = suggested_users(1)

        assert len(results) == 1
        assert results[0]["match_score"] == 1.0
        assert results[0]["name"] == "Bob"

    @patch('OrbitServer.services.matching_service._entity_to_dict')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_no_overlap_scores_zero(self, mock_get_profile, mock_to_dict):
        """Users with completely different interests should score 0.0."""
        mock_get_profile.return_value = {"interests": ["hiking", "music"]}

        other = _make_entity(2, "Bob", ["cooking", "painting"])
        entity = _mock_entity(other)
        mock_to_dict.return_value = other

        import google.cloud.datastore as ds
        mock_client = MagicMock()
        mock_query = MagicMock()
        mock_query.fetch.return_value = [entity]
        mock_client.query.return_value = mock_query

        with patch.object(ds, 'Client', return_value=mock_client):
            results = suggested_users(1)

        assert len(results) == 1
        assert results[0]["match_score"] == 0.0

    @patch('OrbitServer.services.matching_service._entity_to_dict')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_partial_overlap_jaccard(self, mock_get_profile, mock_to_dict):
        """Jaccard = |intersection| / |union|. {A,B,C} vs {B,C,D} = 2/4 = 0.5."""
        mock_get_profile.return_value = {"interests": ["A", "B", "C"]}

        other = _make_entity(2, "Bob", ["B", "C", "D"])
        entity = _mock_entity(other)
        mock_to_dict.return_value = other

        import google.cloud.datastore as ds
        mock_client = MagicMock()
        mock_query = MagicMock()
        mock_query.fetch.return_value = [entity]
        mock_client.query.return_value = mock_query

        with patch.object(ds, 'Client', return_value=mock_client):
            results = suggested_users(1)

        assert results[0]["match_score"] == 0.5

    @patch('OrbitServer.services.matching_service._entity_to_dict')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_score_rounded_to_four_decimals(self, mock_get_profile, mock_to_dict):
        """{A,B,C} vs {A,D,E} = 1/5 = 0.2 — confirm rounding."""
        mock_get_profile.return_value = {"interests": ["A", "B", "C"]}

        other = _make_entity(2, "Bob", ["A", "D", "E"])
        entity = _mock_entity(other)
        mock_to_dict.return_value = other

        import google.cloud.datastore as ds
        mock_client = MagicMock()
        mock_query = MagicMock()
        mock_query.fetch.return_value = [entity]
        mock_client.query.return_value = mock_query

        with patch.object(ds, 'Client', return_value=mock_client):
            results = suggested_users(1)

        assert results[0]["match_score"] == 0.2

    @patch('OrbitServer.services.matching_service._entity_to_dict')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_irrational_score_rounded(self, mock_get_profile, mock_to_dict):
        """{A,B,C} vs {C,D,E,F,G} = 1/7 ≈ 0.1429 — verify 4-decimal rounding."""
        mock_get_profile.return_value = {"interests": ["A", "B", "C"]}

        other = _make_entity(2, "Bob", ["C", "D", "E", "F", "G"])
        entity = _mock_entity(other)
        mock_to_dict.return_value = other

        import google.cloud.datastore as ds
        mock_client = MagicMock()
        mock_query = MagicMock()
        mock_query.fetch.return_value = [entity]
        mock_client.query.return_value = mock_query

        with patch.object(ds, 'Client', return_value=mock_client):
            results = suggested_users(1)

        assert results[0]["match_score"] == round(1 / 7, 4)

    @patch('OrbitServer.services.matching_service._entity_to_dict')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_excludes_own_profile(self, mock_get_profile, mock_to_dict):
        """User should not appear in their own suggestions."""
        mock_get_profile.return_value = {"interests": ["hiking"]}

        own = _make_entity(1, "Self", ["hiking"])
        other = _make_entity(2, "Bob", ["hiking"])

        mock_to_dict.side_effect = [own, other]
        entities = [_mock_entity(own), _mock_entity(other)]

        import google.cloud.datastore as ds
        mock_client = MagicMock()
        mock_query = MagicMock()
        mock_query.fetch.return_value = entities
        mock_client.query.return_value = mock_query

        with patch.object(ds, 'Client', return_value=mock_client):
            results = suggested_users(1)

        names = [r["name"] for r in results]
        assert "Self" not in names
        assert "Bob" in names

    @patch('OrbitServer.services.matching_service._entity_to_dict')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_excludes_profiles_without_name(self, mock_get_profile, mock_to_dict):
        """Incomplete profiles (no name) should be filtered out."""
        mock_get_profile.return_value = {"interests": ["hiking"]}

        no_name = _make_entity(2, "", ["hiking"])
        named = _make_entity(3, "Alice", ["hiking"])

        mock_to_dict.side_effect = [no_name, named]
        entities = [_mock_entity(no_name), _mock_entity(named)]

        import google.cloud.datastore as ds
        mock_client = MagicMock()
        mock_query = MagicMock()
        mock_query.fetch.return_value = entities
        mock_client.query.return_value = mock_query

        with patch.object(ds, 'Client', return_value=mock_client):
            results = suggested_users(1)

        assert len(results) == 1
        assert results[0]["name"] == "Alice"

    @patch('OrbitServer.services.matching_service._entity_to_dict')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_sorted_by_score_descending(self, mock_get_profile, mock_to_dict):
        """Results should be sorted best-match-first."""
        mock_get_profile.return_value = {"interests": ["A", "B", "C", "D"]}

        low = _make_entity(2, "Low", ["X"])        # 0/5 = 0.0
        mid = _make_entity(3, "Mid", ["A", "B"])   # 2/4 = 0.5
        high = _make_entity(4, "High", ["A", "B", "C", "D"])  # 4/4 = 1.0

        mock_to_dict.side_effect = [low, mid, high]
        entities = [_mock_entity(low), _mock_entity(mid), _mock_entity(high)]

        import google.cloud.datastore as ds
        mock_client = MagicMock()
        mock_query = MagicMock()
        mock_query.fetch.return_value = entities
        mock_client.query.return_value = mock_query

        with patch.object(ds, 'Client', return_value=mock_client):
            results = suggested_users(1)

        assert results[0]["name"] == "High"
        assert results[1]["name"] == "Mid"
        assert results[2]["name"] == "Low"

    @patch('OrbitServer.services.matching_service._entity_to_dict')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_limits_to_20_results(self, mock_get_profile, mock_to_dict):
        """Should return at most 20 suggestions."""
        mock_get_profile.return_value = {"interests": ["A"]}

        profiles = [_make_entity(i + 2, f"User{i}", ["A"]) for i in range(25)]
        mock_to_dict.side_effect = profiles
        entities = [_mock_entity(p) for p in profiles]

        import google.cloud.datastore as ds
        mock_client = MagicMock()
        mock_query = MagicMock()
        mock_query.fetch.return_value = entities
        mock_client.query.return_value = mock_query

        with patch.object(ds, 'Client', return_value=mock_client):
            results = suggested_users(1)

        assert len(results) == 20

    @patch('OrbitServer.services.matching_service._entity_to_dict')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_both_empty_interests_score_zero(self, mock_get_profile, mock_to_dict):
        """If both users have empty interests, score should be 0.0 (no division by zero)."""
        mock_get_profile.return_value = {"interests": []}

        other = _make_entity(2, "Bob", [])
        entity = _mock_entity(other)
        mock_to_dict.return_value = other

        import google.cloud.datastore as ds
        mock_client = MagicMock()
        mock_query = MagicMock()
        mock_query.fetch.return_value = [entity]
        mock_client.query.return_value = mock_query

        with patch.object(ds, 'Client', return_value=mock_client):
            results = suggested_users(1)

        assert len(results) == 1
        assert results[0]["match_score"] == 0.0

    @patch('OrbitServer.services.matching_service._entity_to_dict')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_user_has_interests_other_has_none(self, mock_get_profile, mock_to_dict):
        """User with interests vs user with no interests → 0.0."""
        mock_get_profile.return_value = {"interests": ["hiking", "music"]}

        other = _make_entity(2, "Bob", [])
        entity = _mock_entity(other)
        mock_to_dict.return_value = other

        import google.cloud.datastore as ds
        mock_client = MagicMock()
        mock_query = MagicMock()
        mock_query.fetch.return_value = [entity]
        mock_client.query.return_value = mock_query

        with patch.object(ds, 'Client', return_value=mock_client):
            results = suggested_users(1)

        assert results[0]["match_score"] == 0.0

    @patch('OrbitServer.services.matching_service.get_profile')
    def test_no_profile_returns_empty_gracefully(self, mock_get_profile):
        """If the current user has no profile, should not crash."""
        mock_get_profile.return_value = None

        import google.cloud.datastore as ds
        mock_client = MagicMock()
        mock_query = MagicMock()
        mock_query.fetch.return_value = []
        mock_client.query.return_value = mock_query

        with patch.object(ds, 'Client', return_value=mock_client):
            results = suggested_users(1)

        assert results == []

    @patch('OrbitServer.services.matching_service._entity_to_dict')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_match_score_in_output(self, mock_get_profile, mock_to_dict):
        """Every result dict should contain a match_score key."""
        mock_get_profile.return_value = {"interests": ["hiking"]}

        other = _make_entity(2, "Bob", ["hiking"])
        entity = _mock_entity(other)
        mock_to_dict.return_value = other

        import google.cloud.datastore as ds
        mock_client = MagicMock()
        mock_query = MagicMock()
        mock_query.fetch.return_value = [entity]
        mock_client.query.return_value = mock_query

        with patch.object(ds, 'Client', return_value=mock_client):
            results = suggested_users(1)

        for r in results:
            assert "match_score" in r
            assert isinstance(r["match_score"], float)

    @patch('OrbitServer.services.matching_service._entity_to_dict')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_output_contains_only_profile_fields_plus_score(self, mock_get_profile, mock_to_dict):
        """Output should have PROFILE_FIELDS + match_score, no extra keys."""
        mock_get_profile.return_value = {"interests": ["hiking"]}

        other = _make_entity(2, "Bob", ["hiking"])
        entity = _mock_entity(other)
        mock_to_dict.return_value = other

        import google.cloud.datastore as ds
        mock_client = MagicMock()
        mock_query = MagicMock()
        mock_query.fetch.return_value = [entity]
        mock_client.query.return_value = mock_query

        with patch.object(ds, 'Client', return_value=mock_client):
            results = suggested_users(1)

        expected_keys = set(PROFILE_FIELDS) | {"match_score"}
        assert set(results[0].keys()) == expected_keys


# ── suggested_crews ──────────────────────────────────────────────────────────

class TestSuggestedCrews:
    """Test crew suggestion scoring (overlap count, not Jaccard)."""

    @patch('OrbitServer.services.matching_service.list_crews')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_scores_by_tag_overlap(self, mock_get_profile, mock_list_crews):
        mock_get_profile.return_value = {"interests": ["hiking", "music", "gaming"]}
        mock_list_crews.return_value = [
            {"name": "Hikers", "tags": ["hiking", "outdoors"]},
            {"name": "Gamers", "tags": ["gaming", "music", "tech"]},
        ]

        results = suggested_crews(1)

        hikers = next(c for c in results if c["name"] == "Hikers")
        gamers = next(c for c in results if c["name"] == "Gamers")
        assert hikers["match_score"] == 1   # hiking
        assert gamers["match_score"] == 2   # gaming + music

    @patch('OrbitServer.services.matching_service.list_crews')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_sorted_by_score_descending(self, mock_get_profile, mock_list_crews):
        mock_get_profile.return_value = {"interests": ["A", "B", "C"]}
        mock_list_crews.return_value = [
            {"name": "Low", "tags": ["X"]},
            {"name": "High", "tags": ["A", "B", "C"]},
            {"name": "Mid", "tags": ["A"]},
        ]

        results = suggested_crews(1)

        assert results[0]["name"] == "High"
        assert results[0]["match_score"] == 3
        assert results[1]["name"] == "Mid"
        assert results[1]["match_score"] == 1
        assert results[2]["name"] == "Low"
        assert results[2]["match_score"] == 0

    @patch('OrbitServer.services.matching_service.list_crews')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_no_overlap_scores_zero(self, mock_get_profile, mock_list_crews):
        mock_get_profile.return_value = {"interests": ["hiking"]}
        mock_list_crews.return_value = [
            {"name": "Book Club", "tags": ["reading", "literature"]},
        ]

        results = suggested_crews(1)

        assert results[0]["match_score"] == 0

    @patch('OrbitServer.services.matching_service.list_crews')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_crew_with_no_tags(self, mock_get_profile, mock_list_crews):
        mock_get_profile.return_value = {"interests": ["hiking"]}
        mock_list_crews.return_value = [
            {"name": "Empty Crew", "tags": []},
            {"name": "Tagless Crew"},  # no tags key at all
        ]

        results = suggested_crews(1)

        assert all(c["match_score"] == 0 for c in results)

    @patch('OrbitServer.services.matching_service.list_crews')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_limits_to_20(self, mock_get_profile, mock_list_crews):
        mock_get_profile.return_value = {"interests": ["A"]}
        mock_list_crews.return_value = [
            {"name": f"Crew{i}", "tags": ["A"]} for i in range(25)
        ]

        results = suggested_crews(1)

        assert len(results) == 20

    @patch('OrbitServer.services.matching_service.list_crews')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_no_profile_handles_gracefully(self, mock_get_profile, mock_list_crews):
        mock_get_profile.return_value = None
        mock_list_crews.return_value = [{"name": "Crew", "tags": ["A"]}]

        results = suggested_crews(1)

        assert results[0]["match_score"] == 0

    @patch('OrbitServer.services.matching_service.list_crews')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_empty_crews_list(self, mock_get_profile, mock_list_crews):
        mock_get_profile.return_value = {"interests": ["hiking"]}
        mock_list_crews.return_value = []

        results = suggested_crews(1)

        assert results == []


# ── suggested_missions ───────────────────────────────────────────────────────

class TestSuggestedMissions:
    """Test mission suggestion scoring (overlap count)."""

    @patch('OrbitServer.services.matching_service.list_missions')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_scores_by_tag_overlap(self, mock_get_profile, mock_list_missions):
        mock_get_profile.return_value = {"interests": ["hiking", "photography"]}
        mock_list_missions.return_value = [
            {"title": "Photo Walk", "tags": ["photography", "walking"]},
            {"title": "Game Night", "tags": ["gaming"]},
        ]

        results = suggested_missions(1)

        photo = next(m for m in results if m["title"] == "Photo Walk")
        game = next(m for m in results if m["title"] == "Game Night")
        assert photo["match_score"] == 1
        assert game["match_score"] == 0

    @patch('OrbitServer.services.matching_service.list_missions')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_sorted_by_score_descending(self, mock_get_profile, mock_list_missions):
        mock_get_profile.return_value = {"interests": ["A", "B", "C"]}
        mock_list_missions.return_value = [
            {"title": "Low", "tags": []},
            {"title": "High", "tags": ["A", "B", "C"]},
            {"title": "Mid", "tags": ["B"]},
        ]

        results = suggested_missions(1)

        assert results[0]["title"] == "High"
        assert results[0]["match_score"] == 3
        assert results[1]["title"] == "Mid"
        assert results[2]["title"] == "Low"

    @patch('OrbitServer.services.matching_service.list_missions')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_mission_with_no_tags(self, mock_get_profile, mock_list_missions):
        mock_get_profile.return_value = {"interests": ["hiking"]}
        mock_list_missions.return_value = [
            {"title": "Tagless", "tags": []},
            {"title": "No Key"},
        ]

        results = suggested_missions(1)

        assert all(m["match_score"] == 0 for m in results)

    @patch('OrbitServer.services.matching_service.list_missions')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_limits_to_20(self, mock_get_profile, mock_list_missions):
        mock_get_profile.return_value = {"interests": ["A"]}
        mock_list_missions.return_value = [
            {"title": f"Mission{i}", "tags": ["A"]} for i in range(25)
        ]

        results = suggested_missions(1)

        assert len(results) == 20

    @patch('OrbitServer.services.matching_service.list_missions')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_no_profile_handles_gracefully(self, mock_get_profile, mock_list_missions):
        mock_get_profile.return_value = None
        mock_list_missions.return_value = [{"title": "Hike", "tags": ["hiking"]}]

        results = suggested_missions(1)

        assert results[0]["match_score"] == 0

    @patch('OrbitServer.services.matching_service.list_missions')
    @patch('OrbitServer.services.matching_service.get_profile')
    def test_empty_missions_list(self, mock_get_profile, mock_list_missions):
        mock_get_profile.return_value = {"interests": ["hiking"]}
        mock_list_missions.return_value = []

        results = suggested_missions(1)

        assert results == []
