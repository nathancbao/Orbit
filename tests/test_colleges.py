"""Tests for college directory, haversine distance, and distance filtering."""

import pytest

from OrbitServer.utils.colleges import (
    COLLEGES, haversine_miles, college_distance_miles,
    filter_by_distance, college_list,
)


class TestHaversine:
    def test_zero_distance(self):
        assert haversine_miles(38.5382, -121.7617, 38.5382, -121.7617) == 0.0

    def test_davis_to_berkeley_roughly_50_miles(self):
        d = college_distance_miles('uc_davis', 'uc_berkeley')
        assert 40 <= d <= 60

    def test_davis_to_sac_state_under_20_miles(self):
        d = college_distance_miles('uc_davis', 'sac_state')
        assert 0 < d < 20

    def test_davis_to_ucla_far(self):
        d = college_distance_miles('uc_davis', 'ucla')
        assert d > 300

    def test_symmetry(self):
        assert college_distance_miles('uc_davis', 'stanford') == pytest.approx(
            college_distance_miles('stanford', 'uc_davis'))


class TestCollegeDistance:
    def test_unknown_college_returns_none(self):
        assert college_distance_miles('uc_davis', 'hogwarts') is None
        assert college_distance_miles('', 'uc_davis') is None
        assert college_distance_miles(None, None) is None


class TestCollegeList:
    def test_sorted_by_name_with_ids(self):
        colleges = college_list()
        assert len(colleges) == len(COLLEGES)
        names = [c['name'] for c in colleges]
        assert names == sorted(names)
        assert all({'id', 'name', 'lat', 'lng'} <= set(c) for c in colleges)


class TestFilterByDistance:
    def _items(self):
        return [
            {'id': '1', 'college': 'uc_davis'},
            {'id': '2', 'college': 'sac_state'},    # ~15 mi from Davis
            {'id': '3', 'college': 'ucla'},          # ~350 mi from Davis
            {'id': '4', 'college': ''},              # seeded/legacy — always kept
            {'id': '5'},                             # no field — always kept
        ]

    def test_no_college_no_filtering(self):
        user = {'college': '', 'max_distance_miles': 25}
        assert filter_by_distance(self._items(), user) == self._items()

    def test_zero_distance_no_filtering(self):
        user = {'college': 'uc_davis', 'max_distance_miles': 0}
        assert filter_by_distance(self._items(), user) == self._items()

    def test_missing_fields_no_filtering(self):
        assert filter_by_distance(self._items(), {}) == self._items()
        assert filter_by_distance(self._items(), None) == self._items()

    def test_filters_far_colleges(self):
        user = {'college': 'uc_davis', 'max_distance_miles': 25}
        ids = [i['id'] for i in filter_by_distance(self._items(), user)]
        assert ids == ['1', '2', '4', '5']

    def test_large_radius_keeps_everything_within(self):
        user = {'college': 'uc_davis', 'max_distance_miles': 50}
        ids = [i['id'] for i in filter_by_distance(self._items(), user)]
        assert '3' not in ids  # UCLA still too far
        assert '2' in ids

    def test_unknown_user_college_no_filtering(self):
        user = {'college': 'not_a_school', 'max_distance_miles': 25}
        assert filter_by_distance(self._items(), user) == self._items()

    def test_non_int_distance_no_filtering(self):
        user = {'college': 'uc_davis', 'max_distance_miles': 'abc'}
        assert filter_by_distance(self._items(), user) == self._items()
