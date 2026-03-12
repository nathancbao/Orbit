import SwiftUI

struct MainTabView: View {
    @State var profile: Profile
    let onEditProfile: () -> Void
    @Binding var deepLinkFriendId: Int?

    @State private var selectedTab: Tab = .discovery
    @State private var deepLinkProfile: Profile?
    @State private var deepLinkUserId: Int?
    @State private var showDeepLinkProfile = false
    @State private var unreadDMCount: Int = 0

    init(profile: Profile, onEditProfile: @escaping () -> Void, deepLinkFriendId: Binding<Int?>) {
        _profile = State(initialValue: profile)
        self.onEditProfile = onEditProfile
        _deepLinkFriendId = deepLinkFriendId
    }

    enum Tab: CaseIterable {
        case discovery
        case missions
        case pods
        case friends

        var label: String {
            switch self {
            case .discovery: return "Discovery"
            case .missions:  return "Missions"
            case .pods:      return "Pods"
            case .friends:   return "Friends"
            }
        }

        var sfSymbol: String {
            switch self {
            case .discovery: return "safari"
            case .missions:  return "flag"
            case .pods:      return "hexagon"
            case .friends:   return "person.2"
            }
        }

        var sfSymbolFilled: String {
            switch self {
            case .discovery: return "safari.fill"
            case .missions:  return "flag.fill"
            case .pods:      return "hexagon.fill"
            case .friends:   return "person.2.fill"
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

                PodsView(userProfile: $profile, isActive: selectedTab == .pods)
                    .opacity(selectedTab == .pods ? 1 : 0)
                    .allowsHitTesting(selectedTab == .pods)

                FriendsView(userProfile: $profile, isActive: selectedTab == .friends)
                    .opacity(selectedTab == .friends ? 1 : 0)
                    .allowsHitTesting(selectedTab == .friends)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                        if tab == .friends { unreadDMCount = 0 }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: selectedTab == tab ? tab.sfSymbolFilled : tab.sfSymbol)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .foregroundColor(selectedTab == tab ? OrbitTheme.purple : Color(.systemGray2))
                                    .frame(width: 24, height: 24)

                                if tab == .friends && unreadDMCount > 0 {
                                    Text(unreadDMCount > 9 ? "9+" : "\(unreadDMCount)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                        .offset(x: 8, y: -4)
                                }
                            }

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
        .onAppear { resolveDeepLink(deepLinkFriendId) }
        .onChange(of: deepLinkFriendId) { _, friendId in resolveDeepLink(friendId) }
        .onReceive(NotificationCenter.default.publisher(for: .unreadDMCountChanged)) { notification in
            unreadDMCount = notification.userInfo?["count"] as? Int ?? 0
        }
        .sheet(isPresented: $showDeepLinkProfile) {
            if let friendProfile = deepLinkProfile, let userId = deepLinkUserId {
                ProfileDisplayView(
                    profile: friendProfile,
                    otherUserId: userId
                )
            }
        }
    }

    private func resolveDeepLink(_ friendId: Int?) {
        guard let friendId else { return }
        Task {
            if let friendProfile = try? await ProfileService.shared.getUserProfile(id: friendId) {
                deepLinkProfile = friendProfile
                deepLinkUserId = friendId
                showDeepLinkProfile = true
            }
            deepLinkFriendId = nil
        }
    }
}
