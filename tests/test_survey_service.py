"""Tests for services/survey_service.py — post-activity survey logic."""

from unittest.mock import patch, MagicMock


class TestSubmitSurvey:
    """Core survey submission flow."""

    @patch('OrbitServer.services.survey_service.get_pod')
    def test_pod_not_found(self, mock_get_pod):
        from OrbitServer.services.survey_service import submit_survey
        mock_get_pod.return_value = None

        result, err = submit_survey(1, 'bad-pod', 5, [], {})
        assert result is None
        assert 'not found' in err.lower()

    @patch('OrbitServer.services.survey_service.get_pod')
    def test_pod_not_completed(self, mock_get_pod):
        from OrbitServer.services.survey_service import submit_survey
        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'open', 'member_ids': [1, 2],
        }

        result, err = submit_survey(1, 'pod-1', 4, [], {})
        assert result is None
        assert 'completed' in err.lower()

    @patch('OrbitServer.services.survey_service.get_pod')
    def test_not_a_member(self, mock_get_pod):
        from OrbitServer.services.survey_service import submit_survey
        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [2, 3],
        }

        result, err = submit_survey(99, 'pod-1', 5, [], {})
        assert result is None
        assert 'not a member' in err.lower()

    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_duplicate_submission(self, mock_get_pod, mock_existing):
        from OrbitServer.services.survey_service import submit_survey
        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1, 2],
        }
        mock_existing.return_value = {'id': 'survey-old'}

        result, err = submit_survey(1, 'pod-1', 4, [], {})
        assert result is None
        assert 'already submitted' in err.lower()

    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_invalid_enjoyment_rating_too_low(self, mock_get_pod, mock_existing):
        from OrbitServer.services.survey_service import submit_survey
        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1, 2],
        }
        mock_existing.return_value = None

        result, err = submit_survey(1, 'pod-1', 0, [], {})
        assert result is None
        assert 'enjoyment_rating' in err.lower()

    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_invalid_enjoyment_rating_too_high(self, mock_get_pod, mock_existing):
        from OrbitServer.services.survey_service import submit_survey
        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1, 2],
        }
        mock_existing.return_value = None

        result, err = submit_survey(1, 'pod-1', 6, [], {})
        assert result is None
        assert 'enjoyment_rating' in err.lower()

    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_cannot_vote_for_self(self, mock_get_pod, mock_existing):
        from OrbitServer.services.survey_service import submit_survey
        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1, 2],
        }
        mock_existing.return_value = None

        result, err = submit_survey(1, 'pod-1', 4, [], {'1': 'up'})
        assert result is None
        assert 'yourself' in err.lower()

    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_vote_for_non_member(self, mock_get_pod, mock_existing):
        from OrbitServer.services.survey_service import submit_survey
        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1, 2],
        }
        mock_existing.return_value = None

        result, err = submit_survey(1, 'pod-1', 4, [], {'99': 'up'})
        assert result is None
        assert 'not a member' in err.lower()

    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_invalid_vote_value(self, mock_get_pod, mock_existing):
        from OrbitServer.services.survey_service import submit_survey
        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1, 2],
        }
        mock_existing.return_value = None

        result, err = submit_survey(1, 'pod-1', 4, [], {'2': 'maybe'})
        assert result is None
        assert 'invalid vote' in err.lower()

    @patch('OrbitServer.services.survey_service.transactional_pod_update')
    @patch('OrbitServer.services.survey_service.update_history')
    @patch('OrbitServer.services.survey_service.get_history_entry')
    @patch('OrbitServer.services.survey_service.adjust_trust_score')
    @patch('OrbitServer.services.survey_service.update_user')
    @patch('OrbitServer.services.survey_service.get_user')
    @patch('OrbitServer.services.survey_service.create_survey_response')
    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_successful_submission(self, mock_get_pod, mock_existing, mock_create,
                                    mock_get_user, mock_update_user, mock_adjust,
                                    mock_get_hist, mock_update_hist, mock_trans):
        from OrbitServer.services.survey_service import submit_survey

        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1, 2, 3],
            'mission_id': 10,
        }
        mock_existing.return_value = None
        mock_create.return_value = {'id': 'survey-123'}
        mock_get_user.return_value = {'interests': ['Hiking']}
        mock_get_hist.return_value = {'id': 'hist-1'}
        mock_trans.return_value = (None, {})

        result, err = submit_survey(
            user_id=1,
            pod_id='pod-1',
            enjoyment_rating=5,
            added_interests=['Gaming', 'Music'],
            member_votes={'2': 'up', '3': 'down'},
        )

        assert err is None
        assert result['survey_id'] == 'survey-123'

        # Verify survey stored
        mock_create.assert_called_once()

        # Verify interests merged
        mock_update_user.assert_called_once()
        call_args = mock_update_user.call_args
        new_interests = call_args[0][1]['interests']
        assert 'Hiking' in new_interests
        assert 'Gaming' in new_interests
        assert 'Music' in new_interests

        # Verify trust adjustments (2 upvoted, 3 downvoted)
        assert mock_adjust.call_count == 2

        # Verify history enriched
        mock_update_hist.assert_called_once_with('hist-1', {
            'attended': True,
            'enjoyment_rating': 5,
        })

        # Verify pod survey_completed_by updated
        mock_trans.assert_called_once()


class TestInterestMerging:
    """Interest cap and dedup logic."""

    @patch('OrbitServer.services.survey_service.transactional_pod_update')
    @patch('OrbitServer.services.survey_service.update_history')
    @patch('OrbitServer.services.survey_service.get_history_entry')
    @patch('OrbitServer.services.survey_service.adjust_trust_score')
    @patch('OrbitServer.services.survey_service.update_user')
    @patch('OrbitServer.services.survey_service.get_user')
    @patch('OrbitServer.services.survey_service.create_survey_response')
    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_respects_max_interests_cap(self, mock_get_pod, mock_existing, mock_create,
                                         mock_get_user, mock_update_user, mock_adjust,
                                         mock_get_hist, mock_update_hist, mock_trans):
        from OrbitServer.services.survey_service import submit_survey, MAX_INTERESTS

        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1, 2],
            'mission_id': 10,
        }
        mock_existing.return_value = None
        mock_create.return_value = {'id': 'survey-1'}
        # User already has 9 interests
        mock_get_user.return_value = {
            'interests': [f'interest-{i}' for i in range(9)]
        }
        mock_get_hist.return_value = None
        mock_trans.return_value = (None, {})

        submit_survey(1, 'pod-1', 4, ['NewTag1', 'NewTag2'], {})

        call_args = mock_update_user.call_args
        new_interests = call_args[0][1]['interests']
        # Should only add 1 (9 + 1 = 10 = MAX_INTERESTS)
        assert len(new_interests) == MAX_INTERESTS

    @patch('OrbitServer.services.survey_service.transactional_pod_update')
    @patch('OrbitServer.services.survey_service.update_history')
    @patch('OrbitServer.services.survey_service.get_history_entry')
    @patch('OrbitServer.services.survey_service.adjust_trust_score')
    @patch('OrbitServer.services.survey_service.update_user')
    @patch('OrbitServer.services.survey_service.get_user')
    @patch('OrbitServer.services.survey_service.create_survey_response')
    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_deduplicates_interests_case_insensitive(self, mock_get_pod, mock_existing,
                                                       mock_create, mock_get_user,
                                                       mock_update_user, mock_adjust,
                                                       mock_get_hist, mock_update_hist,
                                                       mock_trans):
        from OrbitServer.services.survey_service import submit_survey

        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1, 2],
            'mission_id': 10,
        }
        mock_existing.return_value = None
        mock_create.return_value = {'id': 'survey-1'}
        mock_get_user.return_value = {'interests': ['Hiking', 'Gaming']}
        mock_get_hist.return_value = None
        mock_trans.return_value = (None, {})

        submit_survey(1, 'pod-1', 3, ['hiking', 'Music'], {})

        call_args = mock_update_user.call_args
        new_interests = call_args[0][1]['interests']
        # 'hiking' should NOT be added (Hiking already exists, case insensitive)
        assert len(new_interests) == 3
        assert 'Music' in new_interests

    @patch('OrbitServer.services.survey_service.transactional_pod_update')
    @patch('OrbitServer.services.survey_service.update_history')
    @patch('OrbitServer.services.survey_service.get_history_entry')
    @patch('OrbitServer.services.survey_service.adjust_trust_score')
    @patch('OrbitServer.services.survey_service.update_user')
    @patch('OrbitServer.services.survey_service.get_user')
    @patch('OrbitServer.services.survey_service.create_survey_response')
    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_no_interests_skips_update(self, mock_get_pod, mock_existing, mock_create,
                                        mock_get_user, mock_update_user, mock_adjust,
                                        mock_get_hist, mock_update_hist, mock_trans):
        from OrbitServer.services.survey_service import submit_survey

        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1, 2],
            'mission_id': 10,
        }
        mock_existing.return_value = None
        mock_create.return_value = {'id': 'survey-1'}
        mock_get_hist.return_value = None
        mock_trans.return_value = (None, {})

        submit_survey(1, 'pod-1', 3, [], {})

        # get_user and update_user should NOT be called when no interests to add
        mock_get_user.assert_not_called()
        mock_update_user.assert_not_called()


class TestTrustAdjustment:
    """Trust score deltas from member votes."""

    @patch('OrbitServer.services.survey_service.transactional_pod_update')
    @patch('OrbitServer.services.survey_service.update_history')
    @patch('OrbitServer.services.survey_service.get_history_entry')
    @patch('OrbitServer.services.survey_service.adjust_trust_score')
    @patch('OrbitServer.services.survey_service.update_user')
    @patch('OrbitServer.services.survey_service.get_user')
    @patch('OrbitServer.services.survey_service.create_survey_response')
    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_upvote_increases_trust(self, mock_get_pod, mock_existing, mock_create,
                                     mock_get_user, mock_update_user, mock_adjust,
                                     mock_get_hist, mock_update_hist, mock_trans):
        from OrbitServer.services.survey_service import submit_survey, UPVOTE_DELTA

        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1, 2],
            'mission_id': 10,
        }
        mock_existing.return_value = None
        mock_create.return_value = {'id': 'survey-1'}
        mock_get_hist.return_value = None
        mock_trans.return_value = (None, {})

        submit_survey(1, 'pod-1', 4, [], {'2': 'up'})

        mock_adjust.assert_called_once_with(2, UPVOTE_DELTA)

    @patch('OrbitServer.services.survey_service.transactional_pod_update')
    @patch('OrbitServer.services.survey_service.update_history')
    @patch('OrbitServer.services.survey_service.get_history_entry')
    @patch('OrbitServer.services.survey_service.adjust_trust_score')
    @patch('OrbitServer.services.survey_service.update_user')
    @patch('OrbitServer.services.survey_service.get_user')
    @patch('OrbitServer.services.survey_service.create_survey_response')
    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_downvote_decreases_trust(self, mock_get_pod, mock_existing, mock_create,
                                       mock_get_user, mock_update_user, mock_adjust,
                                       mock_get_hist, mock_update_hist, mock_trans):
        from OrbitServer.services.survey_service import submit_survey, DOWNVOTE_DELTA

        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1, 2],
            'mission_id': 10,
        }
        mock_existing.return_value = None
        mock_create.return_value = {'id': 'survey-1'}
        mock_get_hist.return_value = None
        mock_trans.return_value = (None, {})

        submit_survey(1, 'pod-1', 4, [], {'2': 'down'})

        mock_adjust.assert_called_once_with(2, DOWNVOTE_DELTA)

    @patch('OrbitServer.services.survey_service.transactional_pod_update')
    @patch('OrbitServer.services.survey_service.update_history')
    @patch('OrbitServer.services.survey_service.get_history_entry')
    @patch('OrbitServer.services.survey_service.adjust_trust_score')
    @patch('OrbitServer.services.survey_service.update_user')
    @patch('OrbitServer.services.survey_service.get_user')
    @patch('OrbitServer.services.survey_service.create_survey_response')
    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_no_votes_skips_trust_adjustment(self, mock_get_pod, mock_existing, mock_create,
                                              mock_get_user, mock_update_user, mock_adjust,
                                              mock_get_hist, mock_update_hist, mock_trans):
        from OrbitServer.services.survey_service import submit_survey

        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1, 2],
            'mission_id': 10,
        }
        mock_existing.return_value = None
        mock_create.return_value = {'id': 'survey-1'}
        mock_get_hist.return_value = None
        mock_trans.return_value = (None, {})

        submit_survey(1, 'pod-1', 4, [], {})

        mock_adjust.assert_not_called()


class TestHistoryEnrichment:
    """Verify UserHistory gets updated with enjoyment data."""

    @patch('OrbitServer.services.survey_service.transactional_pod_update')
    @patch('OrbitServer.services.survey_service.update_history')
    @patch('OrbitServer.services.survey_service.get_history_entry')
    @patch('OrbitServer.services.survey_service.adjust_trust_score')
    @patch('OrbitServer.services.survey_service.create_survey_response')
    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_enriches_history_with_enjoyment(self, mock_get_pod, mock_existing, mock_create,
                                              mock_adjust, mock_get_hist, mock_update_hist,
                                              mock_trans):
        from OrbitServer.services.survey_service import submit_survey

        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1],
            'mission_id': 42,
        }
        mock_existing.return_value = None
        mock_create.return_value = {'id': 'survey-1'}
        mock_get_hist.return_value = {'id': 'hist-abc'}
        mock_trans.return_value = (None, {})

        submit_survey(1, 'pod-1', 3, [], {})

        mock_update_hist.assert_called_once_with('hist-abc', {
            'attended': True,
            'enjoyment_rating': 3,
        })

    @patch('OrbitServer.services.survey_service.transactional_pod_update')
    @patch('OrbitServer.services.survey_service.update_history')
    @patch('OrbitServer.services.survey_service.get_history_entry')
    @patch('OrbitServer.services.survey_service.adjust_trust_score')
    @patch('OrbitServer.services.survey_service.create_survey_response')
    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_no_history_entry_skips_update(self, mock_get_pod, mock_existing, mock_create,
                                            mock_adjust, mock_get_hist, mock_update_hist,
                                            mock_trans):
        from OrbitServer.services.survey_service import submit_survey

        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1],
            'mission_id': 42,
        }
        mock_existing.return_value = None
        mock_create.return_value = {'id': 'survey-1'}
        mock_get_hist.return_value = None  # no history entry
        mock_trans.return_value = (None, {})

        submit_survey(1, 'pod-1', 4, [], {})

        mock_update_hist.assert_not_called()

    @patch('OrbitServer.services.survey_service.transactional_pod_update')
    @patch('OrbitServer.services.survey_service.update_history')
    @patch('OrbitServer.services.survey_service.get_history_entry')
    @patch('OrbitServer.services.survey_service.adjust_trust_score')
    @patch('OrbitServer.services.survey_service.create_survey_response')
    @patch('OrbitServer.services.survey_service.get_user_survey_for_pod')
    @patch('OrbitServer.services.survey_service.get_pod')
    def test_no_mission_id_skips_history_update(self, mock_get_pod, mock_existing, mock_create,
                                                 mock_adjust, mock_get_hist, mock_update_hist,
                                                 mock_trans):
        from OrbitServer.services.survey_service import submit_survey

        mock_get_pod.return_value = {
            'id': 'pod-1', 'status': 'completed', 'member_ids': [1],
            'mission_id': None,  # signal-based pod, no mission
        }
        mock_existing.return_value = None
        mock_create.return_value = {'id': 'survey-1'}
        mock_trans.return_value = (None, {})

        submit_survey(1, 'pod-1', 4, [], {})

        mock_get_hist.assert_not_called()
        mock_update_hist.assert_not_called()
