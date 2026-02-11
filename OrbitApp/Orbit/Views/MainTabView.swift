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

    @State private var selectedTab: Tab = .discover
    @StateObject private var friendsViewModel = FriendsViewModel()

    enum Tab {
        case discover
        case friends
        case requests
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

            // Profile Tab
            ProfileDisplayView(
                profile: profile,
                photos: profilePhotos,
                onEdit: onEditProfile
            )
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
            .tag(Tab.profile)
        }
        .environmentObject(friendsViewModel)
        .task {
            await friendsViewModel.loadAll()
        }
    }
}
