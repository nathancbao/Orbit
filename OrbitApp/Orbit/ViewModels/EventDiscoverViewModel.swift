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

    /// Missions the user has joined (in a pod)
    var myMissions: [Mission] {
        allMissions.filter { $0.userPodStatus == "in_pod" }
    }

    /// Missions available to discover (not yet joined)
    var discoverMissions: [Mission] {
        allMissions.filter { $0.userPodStatus != "in_pod" }
    }

    func load(userYear: String) async {
        self.userYear = userYear
        isLoading = true
        errorMessage = nil

        async let suggested = try? MissionService.shared.suggestedMissions()
        async let all = try? MissionService.shared.listMissions(
            tag: filterTag,
            year: showMyYearOnly ? userYear : nil
        )

        let fetchedSuggested = await suggested ?? []
        let fetchedAll = await all ?? []

        suggestedMissions = fetchedSuggested
        allMissions = fetchedAll
        isLoading = false
    }

    func reload() async {
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
}
