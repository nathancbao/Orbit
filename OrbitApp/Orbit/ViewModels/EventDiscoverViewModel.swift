//
//  MissionsViewModel.swift (stored as EventDiscoverViewModel.swift)
//  Orbit
//
//  State for the unified Missions feed. Both Set (fixed-date) and Flex
//  (group-picks-time) missions now live in a single Mission kind served by
//  GET /api/missions, so this view model loads one list and applies the
//  client-side filter + sort the Missions page exposes.
//

import Foundation
import Combine
import SwiftUI

enum MissionSegment: String, CaseIterable {
    case discover = "Explore"
}

/// How the Missions feed is ordered. `.bestMatch` is the default and uses a
/// composite ordering: best match → happening soonest → oldest still standing.
enum MissionSort: String, CaseIterable, Identifiable {
    case bestMatch      = "Best match"
    case soonest        = "Happening soon"
    case furthest       = "Furthest out"
    case recentlyPosted = "Recently posted"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bestMatch:      return "sparkles"
        case .soonest:        return "clock.arrow.circlepath"
        case .furthest:       return "calendar"
        case .recentlyPosted: return "clock.badge"
        }
    }
}

@MainActor
class MissionsViewModel: ObservableObject {
    @Published var suggestedMissions: [Mission] = []
    @Published var allMissions: [Mission] = []         // both modes, from /api/missions
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Filter + sort state
    @Published var filterTag: String?
    @Published var createdByMeOnly = false
    @Published var sort: MissionSort = .bestMatch

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
                Task { @MainActor in await self.reload() }
            }
    }

    // MARK: - Filter helpers

    /// Distinct tags present in the current feed, for the filter sheet picker.
    var availableTags: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for m in allMissions {
            for tag in m.tags where seen.insert(tag.lowercased()).inserted {
                result.append(tag)
            }
        }
        return result.sorted()
    }

    var hasActiveFilter: Bool {
        filterTag != nil || createdByMeOnly || sort != .bestMatch
    }

    // MARK: - Computed feed

    /// Missions the user is part of (created or joined) — surfaced first.
    var myMissions: [Mission] {
        let uid = currentUserId
        return allMissions
            .filter { $0.creatorId == uid || $0.isJoined }
            .sorted { $0.createdAtDate > $1.createdAtDate }
    }

    /// The filtered + sorted list shown in the Missions feed.
    /// Includes missions the user joined or created (badged in the UI).
    var discoverMissions: [Mission] {
        var list = allMissions
        if let tag = filterTag {
            list = list.filter { $0.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) }
        }
        if createdByMeOnly {
            let uid = currentUserId
            list = list.filter { $0.creatorId == uid }
        }
        return sortMissions(list)
    }

    private func sortMissions(_ list: [Mission]) -> [Mission] {
        switch sort {
        case .soonest:
            return list.sorted { $0.sortDate < $1.sortDate }
        case .furthest:
            return list.sorted { $0.sortDate > $1.sortDate }
        case .recentlyPosted:
            return list.sorted { $0.createdAtDate > $1.createdAtDate }
        case .bestMatch:
            // Composite: best match → soonest happening → oldest still standing.
            return list.sorted { a, b in
                let sa = a.matchScore ?? 0, sb = b.matchScore ?? 0
                if abs(sa - sb) > 0.0001 { return sa > sb }
                if a.sortDate != b.sortDate { return a.sortDate < b.sortDate }
                return a.createdAtDate < b.createdAtDate
            }
        }
    }

    private var hasLoaded = false

    // MARK: - Load

    func load(userYear: String = "") async {
        guard !hasLoaded || allMissions.isEmpty else { return }
        self.userYear = userYear
        isLoading = true
        errorMessage = nil

        if let result = try? await MissionService.shared.listMissions() {
            allMissions = result
        }
        isLoading = false
        hasLoaded = true

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
    }

    // MARK: - Actions

    func skipMission(_ mission: Mission) async {
        try? await MissionService.shared.skipMission(id: mission.id)
        allMissions.removeAll { $0.id == mission.id }
        suggestedMissions.removeAll { $0.id == mission.id }
    }

    /// Insert a newly created mission at the top so it appears immediately.
    func insertCreatedMission(_ mission: Mission) {
        allMissions.removeAll { $0.id == mission.id }
        allMissions.insert(mission, at: 0)
    }

    // MARK: - Create (unified)

    @discardableResult
    func createMission(
        mode: MissionMode,
        title: String,
        description: String,
        tags: [String],
        logo: String?,
        images: [String],
        minPodSize: Int,
        maxPodSize: Int,
        location: String = "",
        date: String? = nil,
        startTime: String? = nil,
        endTime: String? = nil,
        availability: [AvailabilitySlot] = [],
        timeRangeStart: Int? = nil,
        timeRangeEnd: Int? = nil,
        links: [String] = [],
        schedulingWindowDays: Int? = nil
    ) async -> Mission? {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let created = try await MissionService.shared.createUnifiedMission(
                mode: mode, title: title, description: description, tags: tags,
                logo: logo, images: images, minPodSize: minPodSize, maxPodSize: maxPodSize,
                location: location, date: date, startTime: startTime, endTime: endTime,
                availability: availability, timeRangeStart: timeRangeStart,
                timeRangeEnd: timeRangeEnd, links: links, schedulingWindowDays: schedulingWindowDays
            )
            // Auto-join the creator so they're in a pod from the start.
            var joined = created
            if let pod = try? await MissionService.shared.joinMission(id: created.id) {
                joined.userPodStatus = "in_pod"
                joined.userPodId = pod.id
                joined.podId = pod.id
            }
            if joined.creatorId == nil { joined.creatorId = currentUserId }
            joined.tags = tags
            joined.logo = logo
            showToastMessage("Mission created!")
            return joined
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Update (unified)

    @discardableResult
    func updateMission(
        id: String,
        mode: MissionMode,
        title: String,
        description: String,
        tags: [String],
        logo: String?,
        images: [String],
        minPodSize: Int,
        maxPodSize: Int,
        location: String = "",
        date: String? = nil,
        startTime: String? = nil,
        endTime: String? = nil,
        availability: [AvailabilitySlot] = [],
        timeRangeStart: Int? = nil,
        timeRangeEnd: Int? = nil,
        links: [String] = [],
        schedulingWindowDays: Int? = nil
    ) async -> Mission? {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            var updated = try await MissionService.shared.updateUnifiedMission(
                id: id, mode: mode, title: title, description: description, tags: tags,
                logo: logo, images: images, minPodSize: minPodSize, maxPodSize: maxPodSize,
                location: location, date: date, startTime: startTime, endTime: endTime,
                availability: availability, timeRangeStart: timeRangeStart,
                timeRangeEnd: timeRangeEnd, links: links, schedulingWindowDays: schedulingWindowDays
            )
            updated.tags = tags
            updated.logo = logo
            replaceInFeed(updated)
            showToastMessage("Mission updated!")
            return updated
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Delete

    /// Delete any mission (both modes now live in the Mission kind).
    func deleteMission(id: String) async {
        do {
            try await MissionService.shared.deleteMission(id: id)
            allMissions.removeAll { $0.id == id }
            showToastMessage("Mission removed")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replaceInFeed(_ mission: Mission) {
        if let idx = allMissions.firstIndex(where: { $0.id == mission.id }) {
            allMissions[idx] = mission
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
