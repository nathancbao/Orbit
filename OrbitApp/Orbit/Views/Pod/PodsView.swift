import SwiftUI

// MARK: - Pods View
// Unified list of all pods the user has joined (missions + signals).

extension Notification.Name {
    static let unreadPodCountChanged = Notification.Name("unreadPodCountChanged")
}

enum PodFilter: String, CaseIterable {
    case all        = "All"
    case leading    = "Leading"
    case scheduling = "Scheduling"
    case scheduled  = "Scheduled"
    case done       = "Done"
}

// Unified item type for the pods list.
private enum PodListItem: Identifiable {
    case pod(Pod)
    case signal(Mission)   // flex signal not yet matched into a pod

    var id: String {
        switch self {
        case .pod(let p):    return "pod-\(p.id)"
        case .signal(let m): return "sig-\(m.id)"
        }
    }
}

struct PodsView: View {
    @Binding var userProfile: Profile
    var isActive: Bool = false
    @State private var pods: [Pod] = []
    @State private var rsvpedFlexMissions: [Mission] = []
    @State private var isLoading = false
    @State private var showProfile = false
    @State private var activeFilter: PodFilter = .all
    @State private var searchText = ""
    @State private var showRecommendations = false
    @State private var recommendedMissions: [Mission] = []
    @State private var recommendedMissionForDetail: Mission? = nil
    @State private var unreadPodIds: Set<String> = []
    @State private var signalPendingDelete: Mission?
    @State private var notifications: [AppNotification] = []

    private var hasUnreadNotifications: Bool {
        notifications.contains { !$0.read }
    }

    /// How many pods the user occupies (max 15) — pods plus flex RSVPs
    /// that haven't been matched into a pod yet.
    private var joinedPodCount: Int {
        let rsvpPodIds = Set(rsvpedFlexMissions.compactMap { $0.podId })
        return pods.filter { !rsvpPodIds.contains($0.id) }.count + rsvpedFlexMissions.count
    }

    private var atPodLimit: Bool { joinedPodCount >= Constants.Validation.maxPods }

    private var currentUserId: Int {
        UserDefaults.standard.integer(forKey: "orbit_user_id")
    }

    /// Unified, filtered, sorted list of pods + unmatched flex signals.
    private var filteredItems: [PodListItem] {
        let userId = currentUserId

        // Pods that already have a pod ID in rsvpedFlexMissions — avoid duplicates.
        let rsvpPodIds = Set(rsvpedFlexMissions.compactMap { $0.podId })

        var items: [PodListItem] = []

        for pod in pods {
            guard !rsvpPodIds.contains(pod.id) else { continue }
            let passes: Bool
            switch activeFilter {
            case .all:        passes = true
            case .leading:    passes = pod.leaderId == userId
            case .scheduling: passes = pod.isFlexPod && pod.isFlexForming
            case .scheduled:  passes = pod.scheduledTime != nil && !pod.isActivityCompleted
            case .done:       passes = pod.isActivityCompleted || pod.status == "completed"
            }
            if passes { items.append(.pod(pod)) }
        }

        for mission in rsvpedFlexMissions {
            let passes: Bool
            switch activeFilter {
            case .all:        passes = true
            case .leading:    passes = mission.creatorId == userId
            case .scheduling: passes = mission.podId == nil
            case .scheduled:  passes = mission.scheduledTime != nil
            case .done:       passes = mission.isCompleted
            }
            if passes { items.append(.signal(mission)) }
        }

        // Sort: scheduled soonest first, then everything else
        let sorted = items.sorted { a, b in
            let dateA: Date
            let dateB: Date
            switch a {
            case .pod(let p): dateA = p.parsedScheduledTime ?? .distantFuture
            case .signal: dateA = .distantFuture
            }
            switch b {
            case .pod(let p): dateB = p.parsedScheduledTime ?? .distantFuture
            case .signal: dateB = .distantFuture
            }
            return dateA < dateB
        }

        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { item in
            switch item {
            case .pod(let p):    return p.displayName.localizedCaseInsensitiveContains(searchText)
            case .signal(let m): return m.displayTitle.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if isLoading && pods.isEmpty && rsvpedFlexMissions.isEmpty {
                    ProgressView()
                        .tint(OrbitTheme.purple)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        // Filter chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(PodFilter.allCases, id: \.self) { filter in
                                    TagFilterChip(
                                        label: filter.rawValue,
                                        isSelected: activeFilter == filter
                                    ) {
                                        activeFilter = filter
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 12)

                        // Search bar + pod count (max 15 pods per person)
                        HStack(spacing: 10) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Search pods", text: $searchText)
                            }
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                            HStack(spacing: 4) {
                                Image(systemName: "person.3.fill")
                                    .font(.caption2)
                                Text("\(joinedPodCount)/\(Constants.Validation.maxPods)")
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(atPodLimit ? Color.orange.opacity(0.15) : Color(.systemGray6))
                            .foregroundColor(atPodLimit ? .orange : .secondary)
                            .clipShape(Capsule())
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                        if filteredItems.isEmpty {
                            VStack(spacing: 12) {
                                Spacer()
                                Image(systemName: "person.3")
                                    .font(.system(size: 36))
                                    .foregroundStyle(OrbitTheme.gradient)
                                Text(pods.isEmpty && rsvpedFlexMissions.isEmpty ? "No Pods Yet" : "No Matches")
                                    .font(.headline)
                                Text("Join a Mission to form a Pod")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ScrollView {
                                VStack(spacing: 14) {
                                    ForEach(filteredItems) { item in
                                        switch item {
                                        case .pod(let pod):
                                            PodRowCard(
                                                pod: pod,
                                                title: pod.displayName,
                                                hasUnread: unreadPodIds.contains(pod.id),
                                                onDismiss: { Task { await loadData() } },
                                                onPodNotFound: { pods.removeAll { $0.id == pod.id } }
                                            )
                                            .padding(.horizontal, 20)
                                        case .signal(let mission):
                                            FlexMissionRsvpCard(
                                                mission: mission,
                                                hasUnread: {
                                                    if let podId = mission.podId { return unreadPodIds.contains(podId) }
                                                    return false
                                                }(),
                                                onDismiss: { Task { await loadData() } },
                                                onPodNotFound: { rsvpedFlexMissions.removeAll { $0.id == mission.id } }
                                            )
                                            .contextMenu {
                                                if mission.isCreatedByCurrentUser {
                                                    Button(role: .destructive) {
                                                        signalPendingDelete = mission
                                                    } label: {
                                                        Label("Delete Mission", systemImage: "trash")
                                                    }
                                                }
                                            }
                                            .padding(.horizontal, 20)
                                        }
                                    }
                                }
                                .padding(.top, 16)
                                .padding(.bottom, 80)
                            }
                            .refreshable { await loadData() }
                        }
                    }
                }
            }
            .navigationTitle("Pods")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            if recommendedMissions.isEmpty {
                                recommendedMissions = (try? await MissionService.shared.suggestedMissions()) ?? []
                            }
                            notifications = (try? await NotificationService.shared.getNotifications()) ?? notifications
                            showRecommendations = true
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.system(size: 18))
                                .fontWeight(.medium)
                                .foregroundStyle(Color.primary)
                                .padding(4)
                            if !recommendedMissions.isEmpty || hasUnreadNotifications {
                                Circle()
                                    .fill(OrbitTheme.pink)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: 0)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showProfile = true } label: {
                        ProfileAvatarView(photo: userProfile.photo, size: 34, name: userProfile.name)
                    }
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileDisplayView(
                profile: userProfile,
                onEdit: { showProfile = false },
                onProfileUpdated: { updated in userProfile = updated }
            )
        }
        .sheet(isPresented: $showRecommendations, onDismiss: {
            // Viewing the inbox marks everything read.
            if hasUnreadNotifications {
                Task { try? await NotificationService.shared.markAllRead() }
                notifications = notifications.map { var n = $0; n.read = true; return n }
            }
        }) {
            PodInboxSheet(
                notifications: notifications,
                recommendations: recommendedMissions,
                onSelectMission: { mission in
                    showRecommendations = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        recommendedMissionForDetail = mission
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: Binding(
            get: { recommendedMissionForDetail != nil },
            set: { if !$0 { recommendedMissionForDetail = nil } }
        )) {
            if let mission = recommendedMissionForDetail {
                MissionDetailView(mission: mission, onJoined: {
                    recommendedMissionForDetail = nil
                })
            }
        }
        .alert(
            "Delete this mission?",
            isPresented: Binding(
                get: { signalPendingDelete != nil },
                set: { if !$0 { signalPendingDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let mission = signalPendingDelete {
                    Task {
                        try? await MissionService.shared.deleteFlexMission(id: mission.id)
                        await loadData()
                    }
                }
                signalPendingDelete = nil
            }
            Button("Cancel", role: .cancel) { signalPendingDelete = nil }
        } message: {
            Text("This removes the mission and its pods for everyone.")
        }
        .task { await loadData() }
        .onChange(of: isActive) { _, active in
            if active {
                Task { await loadData() }
            }
        }
    }

    private func loadData() async {
        isLoading = true
        async let podsResult: [Pod]? = try? APIService.shared.request(
            endpoint: Constants.API.Endpoints.myPods,
            authenticated: true
        )
        async let rsvpsResult: [Mission]? = try? MissionService.shared.rsvpedFlexMissions()
        async let conversationsResult = try? ChatService.shared.getPodConversations()
        async let notificationsResult = try? NotificationService.shared.getNotifications()
        if let newPods = await podsResult {
            pods = newPods
        }
        if let newMissions = await rsvpsResult {
            rsvpedFlexMissions = newMissions
        }
        if let conversations = await conversationsResult {
            refreshUnread(from: conversations)
        }
        if let newNotifications = await notificationsResult {
            notifications = newNotifications
        }
        isLoading = false
    }

    private func refreshUnread(from conversations: [PodConversation]) {
        let currentUserId = UserDefaults.standard.integer(forKey: "orbit_user_id")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var unread = Set<String>()
        for conv in conversations {
            guard let lastSenderId = conv.lastMessageUserId, lastSenderId != currentUserId else { continue }
            guard !conv.lastMessageAt.isEmpty else { continue }
            let lastSeen = UserDefaults.standard.double(forKey: "pod_last_seen_\(conv.podId)")
            let msgTime = formatter.date(from: conv.lastMessageAt)?.timeIntervalSince1970
                ?? ISO8601DateFormatter().date(from: conv.lastMessageAt)?.timeIntervalSince1970
                ?? 0
            if msgTime > lastSeen {
                unread.insert(conv.podId)
            }
        }
        unreadPodIds = unread
        NotificationCenter.default.post(
            name: .unreadPodCountChanged,
            object: nil,
            userInfo: ["count": unread.count]
        )
    }
}

// MARK: - Pod Row Card

struct PodRowCard: View {
    let pod: Pod
    let title: String
    var hasUnread: Bool = false
    var onDismiss: (() -> Void)? = nil
    var onPodNotFound: (() -> Void)? = nil
    @State private var showPod = false
    @State private var showSurvey = false

    var body: some View {
        Button(action: {
            if pod.hasPendingSurvey {
                showSurvey = true
            } else {
                showPod = true
            }
        }) {
            HStack(spacing: 14) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: pod.hasPendingSurvey
                                ? [.green.opacity(0.8), .green.opacity(0.3)]
                                : [OrbitTheme.pink, OrbitTheme.blue],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        if pod.leaderId == UserDefaults.standard.integer(forKey: "orbit_user_id") {
                            MissionBadge(text: "Leader", color: OrbitTheme.purple)
                        }
                    }

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.3")
                                .font(.caption2)
                            Text("\(pod.memberIds.count) members")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)

                        // Below minimum size — compact "+N" chip (N more needed).
                        if pod.membersNeededForMinimum > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "person.fill.badge.plus")
                                    .font(.caption2)
                                Text("+\(pod.membersNeededForMinimum)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                        }
                    }

                    if let time = pod.displayTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(time)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }

                    PodStatusBadge(status: pod.status, hasPendingSurvey: pod.hasPendingSurvey, isActivityCompleted: pod.isActivityCompleted)
                }

                Spacer()

                ZStack(alignment: .topTrailing) {
                    Image(systemName: "message.fill")
                        .foregroundStyle(OrbitTheme.gradient)
                    if hasUnread {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .offset(x: 3, y: -3)
                    }
                }
            }
            .padding(16)
            .background(
                pod.hasPendingSurvey
                    ? LinearGradient(colors: [.green.opacity(0.08), .white], startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [.white, .white], startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPod, onDismiss: {
            onDismiss?()
        }) {
            PodView(podId: pod.id, title: title, onPodNotFound: onPodNotFound)
        }
        .sheet(isPresented: $showSurvey, onDismiss: {
            onDismiss?()
        }) {
            SurveyView(pod: pod)
        }
    }
}

// MARK: - Flex Mission RSVP Card (Black Theme)

struct FlexMissionRsvpCard: View {
    let mission: Mission
    var hasUnread: Bool = false
    var onDismiss: (() -> Void)? = nil
    var onPodNotFound: (() -> Void)? = nil
    @State private var showSheet = false

    var body: some View {
        Button(action: { showSheet = true }) {
            HStack(spacing: 14) {
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: mission.logo ?? "star.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text(mission.displayTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                        if mission.isCreatedByCurrentUser {
                            MissionBadge(text: "Yours", color: OrbitTheme.purple, onDark: true)
                        }
                    }

                    if let groupLabel = mission.flexGroupSizeLabel {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                            Text(groupLabel)
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }

                    if let score = mission.matchScore {
                        Text("\(Int(score * 100))% match")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                (score >= 0.85 ? Color.green : score >= 0.70 ? Color.orange : Color.white.opacity(0.3))
                                    .opacity(0.25)
                            )
                            .foregroundColor(score >= 0.85 ? .green : score >= 0.70 ? .orange : .white.opacity(0.7))
                            .clipShape(Capsule())
                    }

                    if let summary = mission.flexAvailabilitySummary {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(summary)
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }

                    if let status = mission.signalStatus {
                        SignalStatusBadgeDark(status: status)
                    }
                }

                Spacer()

                ZStack(alignment: .topTrailing) {
                    Image(systemName: mission.podId != nil ? "message.fill" : "antenna.radiowaves.left.and.right")
                        .foregroundColor(.white.opacity(0.5))
                    if hasUnread {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .offset(x: 3, y: -3)
                    }
                }
            }
            .padding(16)
            .background(Color(red: 0.1, green: 0.1, blue: 0.14))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet, onDismiss: {
            onDismiss?()
        }) {
            if let podId = mission.podId {
                PodView(podId: podId, title: mission.displayTitle, missionMode: .flex, onPodNotFound: onPodNotFound)
            } else {
                MissionDetailView(mission: mission, onJoined: { onDismiss?() })
            }
        }
    }
}

// MARK: - Pod Inbox Sheet (notifications + recommendations)

struct PodInboxSheet: View {
    let notifications: [AppNotification]
    let recommendations: [Mission]
    let onSelectMission: (Mission) -> Void

    var body: some View {
        NavigationStack {
            List {
                if !notifications.isEmpty {
                    Section("Notifications") {
                        ForEach(notifications) { notif in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: notif.type == "pod_deleted" ? "trash.circle.fill" : "bell.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(OrbitTheme.gradient)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(notif.title)
                                        .font(.subheadline)
                                        .fontWeight(notif.read ? .medium : .semibold)
                                    Text(notif.body)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if !notif.read {
                                    Circle()
                                        .fill(OrbitTheme.pink)
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 6)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Recommended for you") {
                    if recommendations.isEmpty {
                        Text("No recommendations yet. Check back soon!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(recommendations) { mission in
                            Button {
                                onSelectMission(mission)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: mission.logo ?? "sparkles")
                                        .font(.title2)
                                        .foregroundStyle(OrbitTheme.gradient)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mission.displayTitle)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        if let reason = mission.suggestionReason {
                                            Text(reason)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if let score = mission.matchScore {
                                        MatchScoreBadge(score: score)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Signal Status Badge (Dark)

struct SignalStatusBadgeDark: View {
    let status: SignalStatus

    var body: some View {
        Text(status.label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.25))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .active:  return .green
        }
    }
}

// MARK: - Pod Status Badge

struct PodStatusBadge: View {
    let status: String
    var hasPendingSurvey: Bool = false
    var isActivityCompleted: Bool = false

    var label: String {
        if hasPendingSurvey { return "Activity done! Fill out survey!" }
        if isActivityCompleted { return "done — exchange contacts!" }
        switch status {
        case "open":               return "scheduling"
        case "full":               return "scheduling"
        case "meeting_confirmed":  return "scheduled ✓"
        case "completed":          return "done"
        default: return status
        }
    }

    var color: Color {
        if hasPendingSurvey { return .green }
        if isActivityCompleted { return .green }
        switch status {
        case "open":              return .orange
        case "full":              return .orange
        case "meeting_confirmed": return .green
        case "completed":         return .secondary
        default: return .secondary
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
