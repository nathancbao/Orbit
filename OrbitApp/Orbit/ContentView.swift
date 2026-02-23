import SwiftUI

// MARK: - App State

enum AppState {
    case launch
    case auth
    case profileSetup
    case home
}

// MARK: - Content View

struct ContentView: View {
    @State private var appState: AppState = .launch
    @State private var currentProfile: Profile?

    var body: some View {
        Group {
            switch appState {

            case .launch:
                LaunchView {
                    appState = .auth
                }

            case .auth:
                AuthFlowView { isNewUser in
                    if isNewUser {
                        appState = .profileSetup
                    } else {
                        Task { await loadExistingProfile() }
                    }
                }

            case .profileSetup:
                QuickProfileSetupView(
                    onComplete: { profile, _ in
                        currentProfile = profile
                        appState = .home
                    },
                    onCancel: currentProfile != nil ? {
                        appState = .home
                    } : nil
                )

            case .home:
                if let profile = currentProfile {
                    MainTabView(
                        profile: profile,
                        onEditProfile: {
                            appState = .profileSetup
                        }
                    )
                } else {
                    HomeView()
                }
            }
        }
    }

    private func loadExistingProfile() async {
        do {
            let profile = try await ProfileService.shared.getProfile()
            await MainActor.run {
                currentProfile = profile
                appState = .home
            }
        } catch {
            await MainActor.run {
                appState = .profileSetup
            }
        }
    }
}

// MARK: - Fallback Home View

struct HomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("You're in orbit.")
                .font(.title)
                .fontWeight(.bold)
            Text("Discover events to get started.")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
