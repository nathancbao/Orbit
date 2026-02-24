import SwiftUI

struct MainTabView: View {
    let profile: Profile
    let onEditProfile: () -> Void

    @State private var selectedTab: Tab = .discovery

    enum Tab {
        case discovery
        case discover
        case myEvents
        case missions
        case profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            // Discovery Tab (Galaxy View)
            DiscoveryView(userProfile: profile)
                .tabItem {
                    Label("Discovery", systemImage: "moon.stars.fill")
                }
                .tag(Tab.discovery)

            // Discover Tab
            EventDiscoverView(userProfile: profile)
                .tabItem {
                    Label("Events", systemImage: "sparkles")
                }
                .tag(Tab.discover)

            // My Events Tab
            MyEventsView()
                .tabItem {
                    Label("My Events", systemImage: "person.3.fill")
                }
                .tag(Tab.myEvents)

            // Missions Tab
            MissionsView()
                .tabItem {
                    Label("Missions", systemImage: "scope")
                }
                .tag(Tab.missions)

            // Profile Tab
            ProfileDisplayView(profile: profile, onEdit: onEditProfile)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(Tab.profile)
        }
    }
}
