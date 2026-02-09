//
//  MainTabView.swift
//  Orbit
//
//  Main tab navigation after user has created their profile.
//  Shows Discover and Profile tabs.
//

import SwiftUI

struct MainTabView: View {
    let profile: Profile
    let profilePhotos: [UIImage]
    let onEditProfile: () -> Void

    @State private var selectedTab: Tab = .discover

    enum Tab {
        case discover
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
    }
}
