import SwiftUI

struct MainTabView: View {
    let profile: Profile
    let onEditProfile: () -> Void

    @State private var selectedTab: Tab = .discover

    enum Tab {
        case discover
        case myEvents
        case missions
        case profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            // Discover Tab
            EventDiscoverView(userProfile: profile)
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
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
