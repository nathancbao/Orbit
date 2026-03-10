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
    private var refreshCancellable: AnyCancellable?

    private var currentUserId: Int {
        UserDefaults.standard.integer(forKey: "orbit_user_id")
    }

    init() {
        refreshCancellable = NotificationCenter.default
            .publisher(for: .missionsNeedRefresh)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.reload()
                }
            }
    }

    // MARK: - Computed: Combined + Filtered

    /// All missions (set + flex), filtered by mode if set.
    private var combinedMissions: [Mission] {
        let all = allMissions + allFlexMissions
        guard let mode = filterMode else { return all }
        return all.filter { $0.mode == mode }
    }

    /// Missions the user has joined (in a pod for set, or created/RSVPed for flex).
    /// Sorted newest-created first so newly joined missions appear at the top.
    var myMissions: [Mission] {
        let uid = currentUserId
        return combinedMissions
            .filter { m in
                if m.mode == .flex {
                    return m.podId != nil || m.creatorId == uid || m.userPodStatus == "in_pod"
                }
                return m.userPodStatus == "in_pod"
            }
            .sorted { $0.createdAtDate > $1.createdAtDate }
    }

    /// Missions available to discover.
    /// Sorted by event time (soonest first), with flex missions at the bottom.
    var discoverMissions: [Mission] {
        let uid = currentUserId
        let mine = combinedMissions.filter { m in
            if m.mode == .flex {
                return m.creatorId == uid || m.userPodStatus == "in_pod" || m.podId != nil
            }
            return m.userPodStatus == "in_pod"
        }
        let mineIds = Set(mine.map { $0.id })
        let rest = combinedMissions.filter { m in
            guard !mineIds.contains(m.id) else { return false }
            if m.mode == .flex {
                return m.podId == nil && m.creatorId != uid
            }
            return m.userPodStatus != "in_pod"
        }
        // Sort each group: set missions by event time, flex at the end
        let sortByTime: (Mission, Mission) -> Bool = { a, b in
            if a.isFlexMode != b.isFlexMode { return !a.isFlexMode }
            return a.sortDate < b.sortDate
        }
        return mine.sorted(by: sortByTime) + rest.sorted(by: sortByTime)
    }

    private var hasLoaded = false

    // MARK: - Load

    func load(userYear: String) async {
        guard !hasLoaded || allMissions.isEmpty else { return }
        self.userYear = userYear
        isLoading = true
        errorMessage = nil

        // Fetch set missions + flex missions concurrently.
        // Each call is independent — one failing should not wipe the others.
        async let setResult: [Mission]? = try? MissionService.shared.listMissions(
            tag: filterTag,
            year: showMyYearOnly ? userYear : nil
        )
        async let flexResult: [Mission]? = try? MissionService.shared.listFlexMissions()
        async let myFlexResult: [Mission]? = try? MissionService.shared.myFlexMissions()

        let (s, f, mf) = await (setResult, flexResult, myFlexResult)

        // Only update each array when its API call actually returned data.
        if let s = s {
            allMissions = s
        }

        // Merge discover + my flex, dedup by id (only if at least one call succeeded)
        if f != nil || mf != nil {
            var seen = Set<String>()
            var merged: [Mission] = []
            for m in (f ?? []) + (mf ?? []) {
                if seen.insert(m.id).inserted { merged.append(m) }
            }
            // Only replace if we got results; don't wipe existing data on total failure
            if !merged.isEmpty || (f != nil && mf != nil) {
                allFlexMissions = merged
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

    @discardableResult
    func createFlexMission(
        title: String = "",
        activityCategory: ActivityCategory,
        customActivityName: String?,
        minGroupSize: Int,
        maxGroupSize: Int,
        availability: [AvailabilitySlot],
        description: String,
        links: [String] = [],
        timeRangeStart: Int = 9,
        timeRangeEnd: Int = 21
    ) async -> Mission? {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let created = try await MissionService.shared.createFlexMission(
                title: title,
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
            // Auto-RSVP the creator so they're in a pod from the start.
            // Do NOT insert here — caller's onCreated → insertCreatedMission handles it once.
            var rsvped = (try? await MissionService.shared.joinFlexMission(id: created.id)) ?? created
            // Stamp creator identity so myMissions/discoverMissions filters work
            // even if the backend RSVP response omits creator_id.
            if rsvped.creatorId == nil {
                rsvped.creatorId = currentUserId
            }
            rsvped.userPodStatus = "in_pod"
            showToastMessage("Mission created!")
            return rsvped
        } catch {
            errorMessage = error.localizedDescription
            return nil
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
