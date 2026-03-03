//
//  MissionsViewModel.swift (stored as EventDiscoverViewModel.swift)
//  Orbit
//
//  State management for missions feed — supports both Set and Flex modes.
//

import Foundation
import Combine
import SwiftUI

enum MissionSegment: String, CaseIterable {
    case discover = "Discover"
    case mine = "My Missions"
}

@MainActor
class MissionsViewModel: ObservableObject {
    @Published var suggestedMissions: [Mission] = []
    @Published var allMissions: [Mission] = []        // set mode missions from /missions
    @Published var allFlexMissions: [Mission] = []     // flex mode missions from /signals
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var filterTag: String?
    @Published var showMyYearOnly = false
    @Published var filterMode: MissionMode? = nil      // nil = show all
    @Published var isSubmitting = false
    @Published var toastMessage: String?
    @Published var showToast = false

    private var userYear: String = ""
    private var toastTask: Task<Void, Never>?

    private var currentUserId: Int {
        UserDefaults.standard.integer(forKey: "orbit_user_id")
    }

    // MARK: - Computed: Combined + Filtered

    /// All missions (set + flex), filtered by mode if set.
    private var combinedMissions: [Mission] {
        let all = allMissions + allFlexMissions
        guard let mode = filterMode else { return all }
        return all.filter { $0.mode == mode }
    }

    /// Missions the user has joined (in a pod for set, or has podId/is creator for flex).
    var myMissions: [Mission] {
        let uid = currentUserId
        return combinedMissions.filter { m in
            if m.mode == .flex {
                return m.podId != nil || m.creatorId == uid
            }
            return m.userPodStatus == "in_pod"
        }
    }

    /// Missions available to discover (not yet joined).
    /// Missions the user created still appear here at the top even after auto-joining.
    var discoverMissions: [Mission] {
        let uid = currentUserId
        let created = combinedMissions.filter { $0.creatorId == uid && ($0.userPodStatus == "in_pod" || $0.podId != nil) }
        let rest = combinedMissions.filter { m in
            if m.mode == .flex {
                return m.podId == nil && m.creatorId != uid
            }
            return m.userPodStatus != "in_pod"
        }
        return created + rest
    }

    private var hasLoaded = false

    // MARK: - Load

    func load(userYear: String) async {
        guard !hasLoaded || allMissions.isEmpty else { return }
        self.userYear = userYear
        isLoading = true
        errorMessage = nil

        // Fetch set missions + flex missions concurrently.
        do {
            async let setMissions = MissionService.shared.listMissions(
                tag: filterTag,
                year: showMyYearOnly ? userYear : nil
            )
            async let flexMissions = MissionService.shared.listFlexMissions()
            async let myFlex = MissionService.shared.myFlexMissions()

            let (s, f, mf) = try await (setMissions, flexMissions, myFlex)
            allMissions = s

            // Merge discover + my flex, dedup by id
            var seen = Set<String>()
            var merged: [Mission] = []
            for m in f + mf {
                if seen.insert(m.id).inserted { merged.append(m) }
            }
            allFlexMissions = merged
        } catch {
            // If concurrent fetch fails, try individually
            if let s = try? await MissionService.shared.listMissions(tag: filterTag, year: showMyYearOnly ? userYear : nil) {
                allMissions = s
            }
            if let f = try? await MissionService.shared.listFlexMissions() {
                allFlexMissions = f
            }
        }
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

    func applyModeFilter(_ mode: MissionMode?) {
        filterMode = mode
    }

    // MARK: - Actions

    func skipMission(_ mission: Mission) async {
        try? await MissionService.shared.skipMission(id: mission.id)
        allMissions.removeAll { $0.id == mission.id }
        allFlexMissions.removeAll { $0.id == mission.id }
        suggestedMissions.removeAll { $0.id == mission.id }
    }

    /// Insert a newly created mission at the top so it appears immediately.
    func insertCreatedMission(_ mission: Mission) {
        if mission.mode == .flex {
            allFlexMissions.insert(mission, at: 0)
        } else {
            allMissions.insert(mission, at: 0)
        }
    }

    // MARK: - Flex Creation

    func createFlexMission(
        activityCategory: ActivityCategory,
        customActivityName: String?,
        minGroupSize: Int,
        maxGroupSize: Int,
        availability: [AvailabilitySlot],
        description: String,
        links: [String] = [],
        timeRangeStart: Int = 9,
        timeRangeEnd: Int = 21
    ) async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let created = try await MissionService.shared.createFlexMission(
                activityCategory: activityCategory,
                customActivityName: customActivityName,
                minGroupSize: minGroupSize,
                maxGroupSize: maxGroupSize,
                availability: availability,
                description: description,
                links: links,
                timeRangeStart: timeRangeStart,
                timeRangeEnd: timeRangeEnd
            )
            // Auto-RSVP the creator so they're in a pod from the start
            let rsvped = (try? await MissionService.shared.joinFlexMission(id: created.id)) ?? created
            allFlexMissions.insert(rsvped, at: 0)
            showToastMessage("Mission created!")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Flex

    func deleteFlexMission(id: String) async {
        do {
            try await MissionService.shared.deleteFlexMission(id: id)
            allFlexMissions.removeAll { $0.id == id }
            showToastMessage("Mission removed")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Toast

    func showToastMessage(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        withAnimation(.spring(duration: 0.3)) { showToast = true }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { showToast = false }
        }
    }
}
