//
//  SignalsViewModel.swift
//  Orbit
//
//  State management for signals (formerly MissionsViewModel).
//

import Foundation
import Combine
import SwiftUI

@MainActor
class SignalsViewModel: ObservableObject {

    @Published var signals: [Signal] = []
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var toastMessage: String?
    @Published var showToast: Bool = false

    private var toastTask: Task<Void, Never>?

    // MARK: - Computed

    var pendingSignals: [Signal] {
        signals.filter { $0.status == .pending }
    }

    var activeSignals: [Signal] {
        signals.filter { $0.status == .active }
    }

    // MARK: - Load

    func loadSignals() {
        guard signals.isEmpty else { return }
        isLoading = true
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            signals = MockData.mockSignals
            isLoading = false
        }
    }

    // MARK: - Create

    func createSignal(
        activityCategory: ActivityCategory,
        customActivityName: String?,
        minGroupSize: Int,
        maxGroupSize: Int,
        availability: [AvailabilitySlot],
        description: String
    ) {
        let title: String
        if activityCategory == .custom {
            title = customActivityName ?? "Custom Activity"
        } else {
            title = activityCategory.displayName
        }

        let signal = Signal(
            id: UUID().uuidString,
            title: title,
            description: description,
            activityCategory: activityCategory,
            customActivityName: customActivityName,
            minGroupSize: minGroupSize,
            maxGroupSize: maxGroupSize,
            availability: availability,
            status: .pending,
            creatorId: 0,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        signals.insert(signal, at: 0)
        showToastMessage("Signal sent!")
    }

    // MARK: - Delete

    func deleteSignal(id: String) {
        signals.removeAll { $0.id == id }
        showToastMessage("Signal removed")
    }

    // MARK: - Helpers

    private func handleError(_ error: Error) {
        if let e = error as? SignalError {
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
}
