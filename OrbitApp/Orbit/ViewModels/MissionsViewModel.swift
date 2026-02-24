import Foundation
import Combine
import SwiftUI

@MainActor
class MissionsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var missions: [Mission] = []
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false

    @Published var errorMessage: String?
    @Published var showError: Bool = false

    @Published var toastMessage: String?
    @Published var showToast: Bool = false

    private var toastTask: Task<Void, Never>?

    // MARK: - Computed

    var pendingMissions: [Mission] {
        missions.filter { $0.status == .pendingMatch }
    }

    var matchedMissions: [Mission] {
        missions.filter { $0.status == .matched }
    }

    // MARK: - Load (Mock)

    func loadMissions() {
        guard missions.isEmpty else { return }
        isLoading = true
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            missions = Self.mockMissions
            isLoading = false
        }
    }

    // MARK: - Create Mission

    func createMission(
        activityCategory: ActivityCategory,
        customActivityName: String?,
        minGroupSize: Int,
        maxGroupSize: Int,
        availability: [AvailabilitySlot],
        description: String
    ) {
        isSubmitting = true
        defer { isSubmitting = false }

        let title: String
        if activityCategory == .custom {
            title = customActivityName ?? "Custom Activity"
        } else {
            title = activityCategory.displayName
        }

        let mission = Mission(
            id: UUID().uuidString,
            title: title,
            description: description,
            activityCategory: activityCategory,
            customActivityName: customActivityName,
            minGroupSize: minGroupSize,
            maxGroupSize: maxGroupSize,
            availability: availability,
            status: .pendingMatch,
            creatorId: 0,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        missions.insert(mission, at: 0)
        showToastMessage("Mission created!")
    }

    // MARK: - Delete Mission

    func deleteMission(id: String) {
        missions.removeAll { $0.id == id }
        showToastMessage("Mission deleted")
    }

    // MARK: - Private Helpers

    private func handleError(_ error: Error) {
        if let e = error as? MissionError {
            errorMessage = e.errorDescription
        } else {
            errorMessage = "An unexpected error occurred"
        }
        showError = true
    }

    private func showToastMessage(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        withAnimation(.spring(duration: 0.3)) { showToast = true }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { showToast = false }
        }
    }

    // MARK: - Mock Data

    private static var mockMissions: [Mission] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return [
            Mission(
                id: "mock-1",
                title: "Pickup Basketball",
                description: "Looking for people to play 5v5 at the ARC",
                activityCategory: .basketball,
                customActivityName: nil,
                minGroupSize: 6,
                maxGroupSize: 10,
                availability: [
                    AvailabilitySlot(date: today.addingDays(1), timeBlocks: [.afternoon, .evening]),
                    AvailabilitySlot(date: today.addingDays(3), timeBlocks: [.morning, .afternoon]),
                    AvailabilitySlot(date: today.addingDays(5), timeBlocks: [.evening]),
                ],
                status: .pendingMatch,
                creatorId: 0,
                createdAt: ISO8601DateFormatter().string(from: today)
            ),
            Mission(
                id: "mock-2",
                title: "Cafe Study Session",
                description: "Chill study session, bring your laptop",
                activityCategory: .studySession,
                customActivityName: nil,
                minGroupSize: 2,
                maxGroupSize: 5,
                availability: [
                    AvailabilitySlot(date: today.addingDays(0), timeBlocks: [.afternoon]),
                    AvailabilitySlot(date: today.addingDays(1), timeBlocks: [.morning, .afternoon]),
                    AvailabilitySlot(date: today.addingDays(2), timeBlocks: [.afternoon, .evening]),
                    AvailabilitySlot(date: today.addingDays(4), timeBlocks: [.morning]),
                ],
                status: .matched,
                creatorId: 1,
                createdAt: ISO8601DateFormatter().string(from: today.addingDays(-1))
            ),
            Mission(
                id: "mock-3",
                title: "Hiking at Putah Creek",
                description: "",
                activityCategory: .hiking,
                customActivityName: nil,
                minGroupSize: 3,
                maxGroupSize: 8,
                availability: [
                    AvailabilitySlot(date: today.addingDays(6), timeBlocks: [.morning]),
                    AvailabilitySlot(date: today.addingDays(7), timeBlocks: [.morning]),
                    AvailabilitySlot(date: today.addingDays(13), timeBlocks: [.morning, .afternoon]),
                ],
                status: .pendingMatch,
                creatorId: 0,
                createdAt: ISO8601DateFormatter().string(from: today)
            ),
        ]
    }
}

// MARK: - Date Helper

private extension Date {
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}
