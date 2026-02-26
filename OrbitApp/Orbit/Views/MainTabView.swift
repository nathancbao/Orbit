import SwiftUI

struct MainTabView: View {
    let profile: Profile
    let onEditProfile: () -> Void

    @State private var selectedTab: Tab = .discovery

    enum Tab {
        case discovery
        case missions
        case signals
        case pods
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            // Discovery Tab (Galaxy View)
            DiscoveryView(userProfile: profile)
                .tabItem {
                    Label("Discovery", systemImage: "moon.stars.fill")
                }
                .tag(Tab.discovery)

            // Missions Tab (fixed-date events discover feed)
            MissionsView(userProfile: profile)
                .tabItem {
                    Label("Missions", systemImage: "calendar.circle.fill")
                }
                .tag(Tab.missions)

            // Signals Tab (spontaneous activity feed + FAB)
            SignalsView(userProfile: profile)
                .tabItem {
                    Label("Signals", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(Tab.signals)

            // Pods Tab (all joined pods)
            PodsView(userProfile: profile)
                .tabItem {
                    Label("Pods", systemImage: "person.3.fill")
                }
                .tag(Tab.pods)
        }
    }
}
