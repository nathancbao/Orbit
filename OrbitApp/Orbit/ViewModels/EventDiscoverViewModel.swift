//
//  MissionsViewModel.swift (stored as EventDiscoverViewModel.swift)
//  Orbit
//
//  State management for missions feed (formerly EventDiscoverViewModel).
//

import Foundation
import Combine

@MainActor
class MissionsViewModel: ObservableObject {
    @Published var suggestedMissions: [Mission] = []
    @Published var allMissions: [Mission] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var filterTag: String?
    @Published var showMyYearOnly = false

    private var userYear: String = ""

    func load(userYear: String) async {
        self.userYear = userYear
        isLoading = true
        errorMessage = nil

        async let suggested = try? MissionService.shared.suggestedMissions()
        async let all = try? MissionService.shared.listMissions(
            tag: filterTag,
            year: showMyYearOnly ? userYear : nil
        )

        var fetchedSuggested = await suggested ?? []
        var fetchedAll = await all ?? []

        if fetchedAll.isEmpty { fetchedAll = MockData.mockMissions }
        if fetchedSuggested.isEmpty { fetchedSuggested = MockData.mockMissions }

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
