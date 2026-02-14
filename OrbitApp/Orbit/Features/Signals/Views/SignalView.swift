//
//  SignalView.swift
//  Orbit
//
//  Signal discovery orchestrator — routes to the appropriate sub-view
//  based on the user's current signal/pod status.
//
//  States:
//    loading   → spinner
//    noMatch   → empty state with retry
//    newSignal → SignalPopupView
//    hasSignal → LobbyView (waiting for others)
//    hasPod    → PodDetailView (active group)
//

import SwiftUI

struct SignalView: View {
    @State private var response: SignalCheckResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // Space background
            Color(red: 0.05, green: 0.05, blue: 0.15)
                .ignoresSafeArea()

            if isLoading {
                loadingView
            } else if let response = response {
                statusRouter(response)
            } else {
                errorView
            }
        }
        .task {
            await checkSignal()
        }
    }

    // MARK: - Status Router

    @ViewBuilder
    private func statusRouter(_ response: SignalCheckResponse) -> some View {
        switch response.status {
        case .noMatch:
            noMatchView

        case .newSignal, .hasSignal:
            if let signal = response.signal {
                let members = response.members ?? []
                // If user has already partially accepted → lobby
                if !signal.acceptedUserIds.isEmpty && response.status == .hasSignal {
                    LobbyView(
                        signal: signal,
                        members: members,
                        onRefresh: { Task { await checkSignal() } }
                    )
                } else {
                    // New signal or signal not yet accepted
                    SignalPopupView(
                        signal: signal,
                        members: members,
                        onAccept: { Task { await acceptCurrentSignal(signal.id) } },
                        onSkip: { Task { await checkSignal() } }
                    )
                }
            } else {
                noMatchView
            }

        case .hasPod:
            if let pod = response.pod {
                PodDetailView(
                    pod: pod,
                    members: response.members ?? [],
                    revealed: response.revealed ?? pod.revealed
                )
            } else {
                noMatchView
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)

            Text("Scanning for signals...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - No Match View

    private var noMatchView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text("No Signals Right Now")
                .font(.title3.bold())
                .foregroundColor(.white)

            Text("We couldn't find compatible matches at the moment. Check back later as more people join!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: { Task { await checkSignal() } }) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
            }

            Spacer()
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Something went wrong")
                .font(.headline)
                .foregroundColor(.white)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            Button(action: { Task { await checkSignal() } }) {
                Text("Retry")
                    .foregroundColor(.blue)
            }
        }
    }

    // MARK: - Actions

    private func checkSignal() async {
        isLoading = true
        errorMessage = nil
        do {
            response = try await SignalService.shared.checkForSignal()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func acceptCurrentSignal(_ signalId: String) async {
        isLoading = true
        errorMessage = nil
        do {
            response = try await SignalService.shared.acceptSignal(signalId: signalId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    SignalView()
}
