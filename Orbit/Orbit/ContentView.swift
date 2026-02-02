//
//  ContentView.swift
//  Orbit
//
//  Created by Adrian Nguyen on 2/1/26.
//
//  MAIN APP COORDINATOR
//  This file controls the main navigation flow of the app.
//  It decides which screen to show based on the current AppState.
//
//  FLOW: Auth -> Profile Setup -> Home (Profile Display)
//
//  INTEGRATION NOTES FOR TEAMMATES:
//  - Friend 2 (Auth): When auth completes, set appState to .profileSetup (new user)
//    or .home (returning user with existing profile)
//  - The completedProfile and profilePhotos are passed to ProfileSetupView
//    when editing, so data persists between edits
//

import SwiftUI

// MARK: - App State
// Controls which screen is currently displayed
// Add more cases here if you need additional screens (e.g., .onboarding, .settings)
enum AppState {
    case auth           // Show login/verification screens
    case profileSetup   // Show profile creation/editing flow
    case home           // Show completed profile
}

// MARK: - Main Content View
struct ContentView: View {
    // Current screen state - changing this switches the displayed view
    @State private var appState: AppState = .auth

    // Stores the completed profile data (persists during app session)
    // This gets passed back to ProfileSetupView when user taps "Edit"
    @State private var completedProfile: Profile?
    @State private var profilePhotos: [UIImage] = []

    var body: some View {
        Group {
            switch appState {
            // MARK: Auth State
            case .auth:
                AuthFlowView { isNewUser in
                    if isNewUser {
                        appState = .profileSetup
                    } else {
                        // Returning user - load their profile
                        Task {
                            await loadExistingProfile()
                        }
                    }
                }

            // MARK: Profile Setup State
            case .profileSetup:
                // Profile creation/editing flow (5 steps)
                // Passes existing data if user is editing (nil if new user)
                ProfileSetupView(
                    initialProfile: completedProfile,
                    initialPhotos: profilePhotos
                ) { profile, photos in
                    // Called when user completes profile setup
                    completedProfile = profile
                    profilePhotos = photos
                    appState = .home
                }

            // MARK: Home State (Tab View)
            case .home:
                if let profile = completedProfile {
                    MainTabView(
                        profile: profile,
                        profilePhotos: profilePhotos,
                        onEditProfile: {
                            appState = .profileSetup
                        }
                    )
                } else {
                    // Fallback if no profile (shouldn't happen in normal flow)
                    HomeView()
                }
            }
        }
    }

    // Load profile for returning users
    private func loadExistingProfile() async {
        do {
            let profile = try await ProfileService.shared.getProfile()
            await MainActor.run {
                completedProfile = profile
                appState = .home
            }
        } catch {
            // If profile load fails, treat as new user
            await MainActor.run {
                appState = .profileSetup
            }
        }
    }
}

// MARK: - Dev Bypass View
// Temporary view for testing without auth
// Remove or hide this when auth is implemented
struct DevBypassView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Orbit")
                    .font(.system(size: 48, weight: .bold))
                Text("Find your crew")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 16) {
                Text("DEV MODE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)

                Text("Auth is being implemented by your teammate.\nTap below to skip to profile setup.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: onContinue) {
                    Text("Skip to Profile Setup")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Home View (Fallback)
// Simple placeholder - shown if somehow we reach home without a profile
struct HomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Profile Complete!")
                .font(.title)
                .fontWeight(.bold)

            Text("Your profile has been saved.\nMore features coming soon.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
