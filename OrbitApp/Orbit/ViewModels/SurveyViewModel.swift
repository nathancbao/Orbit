//
//  SurveyViewModel.swift
//  Orbit
//
//  State management for the post-activity survey.
//

import Foundation
import Combine

@MainActor
class SurveyViewModel: ObservableObject {
    @Published var enjoymentRating: Int = 0
    @Published var selectedInterests: Set<String> = []
    @Published var memberVotes: [Int: String] = [:]  // userId -> "up"/"down"
    @Published var isSubmitting = false
    @Published var didSubmit = false
    @Published var errorMessage: String?

    let pod: Pod

    /// Tags from the mission that the user doesn't already have
    var availableTags: [String] {
        pod.missionTags
    }

    /// Pod members excluding the current user
    var otherMembers: [PodMember] {
        let currentUserId = UserDefaults.standard.integer(forKey: "orbit_user_id")
        return (pod.members ?? []).filter { $0.userId != currentUserId }
    }

    var canSubmit: Bool {
        enjoymentRating > 0
    }

    init(pod: Pod) {
        self.pod = pod
    }

    func toggleInterest(_ tag: String) {
        if selectedInterests.contains(tag) {
            selectedInterests.remove(tag)
        } else {
            selectedInterests.insert(tag)
        }
    }

    func toggleVote(for userId: Int, vote: String) {
        if memberVotes[userId] == vote {
            memberVotes.removeValue(forKey: userId)
        } else {
            memberVotes[userId] = vote
        }
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil

        let votesPayload = Dictionary(
            uniqueKeysWithValues: memberVotes.map { (String($0.key), $0.value) }
        )

        do {
            _ = try await PodService.shared.submitSurvey(
                podId: pod.id,
                enjoymentRating: enjoymentRating,
                addedInterests: Array(selectedInterests),
                memberVotes: votesPayload
            )
            didSubmit = true
        } catch {
            errorMessage = "Failed to submit survey. Please try again."
        }

        isSubmitting = false
    }
}
