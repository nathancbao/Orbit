import SwiftUI

struct MainTabView: View {
    @State var profile: Profile
    let onEditProfile: () -> Void

    @State private var selectedTab: Tab = .discovery

    init(profile: Profile, onEditProfile: @escaping () -> Void) {
        _profile = State(initialValue: profile)
        self.onEditProfile = onEditProfile
    }

    enum Tab: CaseIterable {
        case discovery
        case missions
        case signals
        case pods

        var label: String {
            switch self {
            case .discovery: return "Discovery"
            case .missions:  return "Missions"
            case .signals:   return "Signals"
            case .pods:      return "Pods"
            }
        }

        var blankIcon: String {
            switch self {
            case .discovery: return "discoveryNavBlank"
            case .missions:  return "missionNavBlank"
            case .signals:   return "signalNavBlank"
            case .pods:      return "podsNavBlank"
            }
        }

        var colorIcon: String {
            switch self {
            case .discovery: return "discoveryNavColor"
            case .missions:  return "missionNavColor"
            case .signals:   return "signalNavColor"
            case .pods:      return "podsNavColor"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content area — ZStack keeps all views alive so state persists across tab switches
            ZStack {
                DiscoveryView(userProfile: $profile, isActive: selectedTab == .discovery)
                    .opacity(selectedTab == .discovery ? 1 : 0)
                    .allowsHitTesting(selectedTab == .discovery)

                MissionsView(userProfile: $profile)
                    .opacity(selectedTab == .missions ? 1 : 0)
                    .allowsHitTesting(selectedTab == .missions)

                SignalsView(userProfile: $profile)
                    .opacity(selectedTab == .signals ? 1 : 0)
                    .allowsHitTesting(selectedTab == .signals)

                PodsView(userProfile: $profile, isActive: selectedTab == .pods)
                    .opacity(selectedTab == .pods ? 1 : 0)
                    .allowsHitTesting(selectedTab == .pods)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(selectedTab == tab ? tab.colorIcon : tab.blankIcon)
                                .renderingMode(.original)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)

                            Text(tab.label)
                                .font(.caption2)
                                .foregroundColor(
                                    selectedTab == tab
                                        ? OrbitTheme.purple
                                        : .gray
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                    }
                }
            }
            .padding(.bottom, 20)
            .background(
                Color.white
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -2)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
