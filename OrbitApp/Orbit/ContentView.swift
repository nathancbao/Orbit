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
    @Binding var deepLinkFriendId: Int?
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
                        },
                        deepLinkFriendId: $deepLinkFriendId
                    )
                } else {
                    // No profile loaded — send to setup instead of dead screen
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("You have no profile. Please set one up to continue.")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.12))

                        QuickProfileSetupView(
                            onComplete: { profile, _ in
                                currentProfile = profile
                                appState = .home
                            },
                            onCancel: nil
                        )
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didLogout)) { _ in
            currentProfile = nil
            appState = .auth
        }
        .task {
            if appState == .launch && AuthService.shared.isLoggedIn() {
                await loadExistingProfile()
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


#Preview {
    ContentView(deepLinkFriendId: .constant(nil))
}
