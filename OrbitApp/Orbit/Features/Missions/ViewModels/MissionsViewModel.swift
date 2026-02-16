//
//  MissionsViewModel.swift
//  Orbit
//
//  State management for missions with optimistic UI for join/leave.
//

import Foundation
import Combine

@MainActor
class MissionsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var discoverMissions: [Mission] = []
    @Published var myMissions: [Mission] = []
    @Published var participants: [MissionParticipant] = []

    @Published var selectedSegment: MissionFeedSegment = .discover
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false

    @Published var errorMessage: String?
    @Published var showError: Bool = false

    @Published var successMessage: String?
    @Published var showSuccess: Bool = false

    // MARK: - Computed

    var currentMissions: [Mission] {
        selectedSegment == .discover ? discoverMissions : myMissions
    }

    // MARK: - Load Data

    func loadAll() async {
        isLoading = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadDiscoverMissions() }
            group.addTask { await self.loadMyMissions() }
        }
        isLoading = false
    }

    func loadDiscoverMissions() async {
        do {
            discoverMissions = try await MissionService.shared.listMissions()
        } catch {
            handleError(error)
        }
    }

    func loadMyMissions() async {
        do {
            myMissions = try await MissionService.shared.getMyMissions()
        } catch {
            handleError(error)
        }
    }

    func loadParticipants(missionId: String) async {
        do {
            participants = try await MissionService.shared.getParticipants(missionId: missionId)
        } catch {
            handleError(error)
        }
    }

    // MARK: - Create Mission

    func createMission(data: [String: Any]) async -> Mission? {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let mission = try await MissionService.shared.createMission(data: data)
            discoverMissions.insert(mission, at: 0)
            myMissions.insert(mission, at: 0)
            showSuccessMessage("Mission created!")
            return mission
        } catch {
            handleError(error)
            return nil
        }
    }

    // MARK: - Update Mission

    func updateMission(id: String, data: [String: Any]) async -> Mission? {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let updated = try await MissionService.shared.updateMission(id: id, data: data)
            replaceMission(updated)
            showSuccessMessage("Mission updated!")
            return updated
        } catch {
            handleError(error)
            return nil
        }
    }

    // MARK: - Delete Mission

    func deleteMission(id: String) async -> Bool {
        // Optimistic: remove locally
        let backupDiscover = discoverMissions
        let backupMy = myMissions
        discoverMissions.removeAll { $0.id == id }
        myMissions.removeAll { $0.id == id }

        do {
            try await MissionService.shared.deleteMission(id: id)
            showSuccessMessage("Mission deleted")
            return true
        } catch {
            // Revert
            discoverMissions = backupDiscover
            myMissions = backupMy
            handleError(error)
            return false
        }
    }

    // MARK: - RSVP (Optimistic)

    func rsvpToMission(_ mission: Mission, rsvpType: RSVPType) async {
        // Optimistic update
        let optimistic = Mission(
            id: mission.id, title: mission.title, description: mission.description,
            tags: mission.tags, location: mission.location,
            startTime: mission.startTime, endTime: mission.endTime,
            latitude: mission.latitude, longitude: mission.longitude,
            links: mission.links, images: mission.images,
            maxParticipants: mission.maxParticipants, creatorId: mission.creatorId,
            hardRsvpCount: mission.hardRsvpCount + (rsvpType == .hard ? 1 : 0),
            softRsvpCount: mission.softRsvpCount + (rsvpType == .soft ? 1 : 0),
            createdAt: mission.createdAt
        )
        replaceMission(optimistic)

        do {
            try await MissionService.shared.rsvpToMission(id: mission.id, rsvpType: rsvpType)
            // Also add to my missions
            if !myMissions.contains(where: { $0.id == mission.id }) {
                myMissions.append(optimistic)
            }
        } catch {
            // Revert
            replaceMission(mission)
            handleError(error)
        }
    }

    // MARK: - Leave Mission (Optimistic)

    func leaveMission(_ mission: Mission) async {
        let rsvpType = MissionService.shared.getUserRsvpType(missionId: mission.id) ?? .hard

        // Optimistic update
        let optimistic = Mission(
            id: mission.id, title: mission.title, description: mission.description,
            tags: mission.tags, location: mission.location,
            startTime: mission.startTime, endTime: mission.endTime,
            latitude: mission.latitude, longitude: mission.longitude,
            links: mission.links, images: mission.images,
            maxParticipants: mission.maxParticipants, creatorId: mission.creatorId,
            hardRsvpCount: max(0, mission.hardRsvpCount - (rsvpType == .hard ? 1 : 0)),
            softRsvpCount: max(0, mission.softRsvpCount - (rsvpType == .soft ? 1 : 0)),
            createdAt: mission.createdAt
        )
        replaceMission(optimistic)
        myMissions.removeAll { $0.id == mission.id && !MissionService.shared.isCreator(mission: mission) }

        do {
            try await MissionService.shared.leaveMission(id: mission.id)
        } catch {
            // Revert
            replaceMission(mission)
            if !myMissions.contains(where: { $0.id == mission.id }) {
                myMissions.append(mission)
            }
            handleError(error)
        }
    }

    // MARK: - Helpers

    func getUserRsvpType(missionId: String) -> RSVPType? {
        MissionService.shared.getUserRsvpType(missionId: missionId)
    }

    func isCreator(_ mission: Mission) -> Bool {
        MissionService.shared.isCreator(mission: mission)
    }

    private func replaceMission(_ mission: Mission) {
        if let i = discoverMissions.firstIndex(where: { $0.id == mission.id }) {
            discoverMissions[i] = mission
        }
        if let i = myMissions.firstIndex(where: { $0.id == mission.id }) {
            myMissions[i] = mission
        }
    }

    private func handleError(_ error: Error) {
        if let missionError = error as? MissionError {
            errorMessage = missionError.errorDescription
        } else if let networkError = error as? NetworkError {
            errorMessage = networkError.errorDescription
        } else {
            errorMessage = "An unexpected error occurred"
        }
        showError = true
    }

    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccess = true
    }
}
