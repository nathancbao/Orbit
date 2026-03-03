//
//  MissionsViewModel.swift (stored as EventDiscoverViewModel.swift)
//  Orbit
//
//  State management for missions feed (formerly EventDiscoverViewModel).
//

import Foundation
import Combine

enum MissionSegment: String, CaseIterable {
    case discover = "Discover"
    case mine = "My Missions"
}

@MainActor
class MissionsViewModel: ObservableObject {
    @Published var suggestedMissions: [Mission] = []
    @Published var allMissions: [Mission] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var filterTag: String?
    @Published var showMyYearOnly = false

    private var userYear: String = ""

    private var currentUserId: Int {
        UserDefaults.standard.integer(forKey: "orbit_user_id")
    }

    /// Missions the user has joined (in a pod)
    var myMissions: [Mission] {
        allMissions.filter { $0.userPodStatus == "in_pod" }
    }

    /// Missions available to discover (not yet joined).
    /// Missions the user created still appear here at the top even after auto-joining.
    var discoverMissions: [Mission] {
        let uid = currentUserId
        let created = allMissions.filter { $0.creatorId == uid && $0.userPodStatus == "in_pod" }
        let rest = allMissions.filter { $0.userPodStatus != "in_pod" }
        return created + rest
    }

    private var hasLoaded = false

    func load(userYear: String) async {
        guard !hasLoaded || allMissions.isEmpty else { return }
        self.userYear = userYear
        isLoading = true
        errorMessage = nil

        // Fetch main list first — show it as soon as it arrives.
        // Suggested missions load in background (can be slow due to AI matching).
        do {
            allMissions = try await MissionService.shared.listMissions(
                tag: filterTag,
                year: showMyYearOnly ? userYear : nil
            )
        } catch { /* empty list is fine */ }
        isLoading = false
        hasLoaded = true

        // Suggested missions load after — won't block the main feed.
        if let suggested = try? await MissionService.shared.suggestedMissions() {
            suggestedMissions = suggested
        }
    }

    func reload() async {
        hasLoaded = false
        await load(userYear: userYear)
    }

    func applyTag(_ tag: String?) async {
        filterTag = tag
        await reload()
    }

    func toggleYearFilter() async {
        showMyYearOnly.toggle()
        await reload()
    }

    func skipMission(_ mission: Mission) async {
        try? await MissionService.shared.skipMission(id: mission.id)
        allMissions.removeAll { $0.id == mission.id }
        suggestedMissions.removeAll { $0.id == mission.id }
    }

    /// Insert a newly created mission at the top of allMissions so it appears immediately.
    func insertCreatedMission(_ mission: Mission) {
        allMissions.insert(mission, at: 0)
    }
}
