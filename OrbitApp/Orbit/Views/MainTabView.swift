//
//  MainTabView.swift
//  Orbit
//
//  Main tab navigation after user has created their profile.
//  Shows Discover, Friends, Requests, and Profile tabs.
//

import SwiftUI

struct MainTabView: View {
    let profile: Profile
    let profilePhotos: [UIImage]
    let onEditProfile: () -> Void
    var onVibeCheckComplete: ((Profile) -> Void)? = nil

    @State private var selectedTab: Tab = .discover
    @State private var showVibeCheckSheet = false
    @StateObject private var friendsViewModel = FriendsViewModel()
    @StateObject private var missionsViewModel = MissionsViewModel()
    @StateObject private var vibeCheckVM = ProfileViewModel()

    enum Tab {
        case discover
        case friends
        case requests
        case missions
        case profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Discover Tab
            DiscoverView(userProfile: profile)
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
                }
                .tag(Tab.discover)

            // Friends Tab
            FriendsListView()
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }
                .tag(Tab.friends)

            // Requests Tab
            RequestsListView()
                .tabItem {
                    Label("Requests", systemImage: "envelope")
                }
                .tag(Tab.requests)
                .badge(friendsViewModel.incomingRequestCount)

            // Missions Tab
            MissionsView()
                .tabItem {
                    Label("Missions", systemImage: "flag.fill")
                }
                .tag(Tab.missions)

            // Profile Tab
            ProfileDisplayView(
                profile: profile,
                photos: profilePhotos,
                onEdit: onEditProfile,
                onTakeVibeCheck: {
                    // Pre-populate the VM with current profile data
                    vibeCheckVM.selectedInterests = Set(profile.interests)
                    vibeCheckVM.introvertExtrovert = profile.personality.introvertExtrovert
                    vibeCheckVM.spontaneousPlanner = profile.personality.spontaneousPlanner
                    vibeCheckVM.activeRelaxed = profile.personality.activeRelaxed
                    vibeCheckVM.name = profile.name
                    vibeCheckVM.age = profile.age
                    vibeCheckVM.city = profile.location.city
                    vibeCheckVM.state = profile.location.state
                    vibeCheckVM.bio = profile.bio
                    vibeCheckVM.groupSize = profile.socialPreferences.groupSize
                    vibeCheckVM.meetingFrequency = profile.socialPreferences.meetingFrequency
                    vibeCheckVM.preferredTimes = Set(profile.socialPreferences.preferredTimes)
                    showVibeCheckSheet = true
                }
            )
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
            .tag(Tab.profile)
        }
        .environmentObject(friendsViewModel)
        .environmentObject(missionsViewModel)
        .fullScreenCover(isPresented: $showVibeCheckSheet) {
            vibeCheckSheet
        }
        .task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.friendsViewModel.loadAll() }
                group.addTask { await self.missionsViewModel.loadAll() }
            }
        }
    }

    // MARK: - Vibe Check Sheet
    private var vibeCheckSheet: some View {
        ZStack {
            VibeCheckView(viewModel: vibeCheckVM)

            // Done button (shown after MBTI result)
            if vibeCheckVM.isVibeCheckComplete {
                VStack {
                    HStack {
                        Spacer()
                        Button("Done") {
                            showVibeCheckSheet = false
                            let updatedProfile = vibeCheckVM.buildProfile()
                            onVibeCheckComplete?(updatedProfile)
                            // Save to server
                            Task {
                                try? await ProfileService.shared.updateProfile(updatedProfile)
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(20)
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 16)
                    Spacer()
                }
            }

            // Close button (top-left, always visible)
            VStack {
                HStack {
                    Button {
                        showVibeCheckSheet = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.leading, 20)
                    Spacer()
                }
                .padding(.top, 16)
                Spacer()
            }
        }
    }
}
