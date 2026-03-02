//
//  SignalsViewModel.swift
//  Orbit
//
//  State management for signals — wired to /api/missions backend.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class SignalsViewModel: ObservableObject {

    @Published var discoverSignals: [Signal] = []
    @Published var mySignals: [Signal] = []
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var toastMessage: String?
    @Published var showToast: Bool = false

    private var toastTask: Task<Void, Never>?
    private var hasLoaded = false

    // MARK: - Load

    func loadSignals() async {
        // Only skip if we already have data. If previous load failed (empty), retry.
        guard !hasLoaded || (discoverSignals.isEmpty && mySignals.isEmpty) else { return }
        isLoading = true
        defer { isLoading = false }

        async let discover = try? SignalService.shared.discoverSignals()
        async let mine = try? SignalService.shared.mySignals()

        discoverSignals = await discover ?? []
        mySignals = await mine ?? []
        hasLoaded = true
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }

        async let discover = try? SignalService.shared.discoverSignals()
        async let mine = try? SignalService.shared.mySignals()

        discoverSignals = await discover ?? []
        mySignals = await mine ?? []
    }

    // MARK: - Create

    func createSignal(
        activityCategory: ActivityCategory,
        customActivityName: String?,
        minGroupSize: Int,
        maxGroupSize: Int,
        availability: [AvailabilitySlot],
        description: String,
        links: [String] = []
    ) async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let created = try await SignalService.shared.createSignal(
                activityCategory: activityCategory,
                customActivityName: customActivityName,
                minGroupSize: minGroupSize,
                maxGroupSize: maxGroupSize,
                availability: availability,
                description: description,
                links: links
            )
            // Insert locally for instant feedback, then refresh in background.
            discoverSignals.insert(created, at: 0)
            mySignals.insert(created, at: 0)
            showToastMessage("Signal sent!")
        } catch {
            handleError(error)
        }
    }

    // MARK: - Delete

    func deleteSignal(id: String) async {
        do {
            try await SignalService.shared.deleteSignal(id: id)
            discoverSignals.removeAll { $0.id == id }
            mySignals.removeAll { $0.id == id }
            showToastMessage("Signal removed")
        } catch {
            handleError(error)
        }
    }

    // MARK: - Helpers

    private func handleError(_ error: Error) {
        if let e = error as? SignalError {
            errorMessage = e.errorDescription
        } else if let e = error as? NetworkError {
            errorMessage = e.errorDescription
        } else {
            errorMessage = "An unexpected error occurred"
        }
        showError = true
    }

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
