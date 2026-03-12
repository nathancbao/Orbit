import SwiftUI

// MARK: - Pods View
// Unified list of all pods the user has joined (missions + signals).

enum PodSegment: String, CaseIterable {
    case set = "Set"
    case flex = "Flex"
}

struct PodsView: View {
    @Binding var userProfile: Profile
    var isActive: Bool = false
    @State private var pods: [Pod] = []
    @State private var rsvpedFlexMissions: [Mission] = []
    @State private var isLoading = false
    @State private var showProfile = false
    @State private var segment: PodSegment = .set
    @State private var searchText = ""
    @State private var showRecommendations = false
    @State private var recommendedMissions: [Mission] = []
    @State private var recommendedMissionForDetail: Mission? = nil

    /// Set pods sorted by scheduled time (soonest first), filtered by search.
    /// Excludes flex pods so they only appear in the Flex tab.
    private var sortedPods: [Pod] {
        let setPods = pods.filter { !$0.isFlexPod }
        let sorted = setPods.sorted { a, b in
            let dateA = a.parsedScheduledTime ?? .distantFuture
            let dateB = b.parsedScheduledTime ?? .distantFuture
            return dateA < dateB
        }
        if searchText.isEmpty { return sorted }
        return sorted.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    /// Flex missions filtered by search.
    private var filteredFlexMissions: [Mission] {
        if searchText.isEmpty { return rsvpedFlexMissions }
        return rsvpedFlexMissions.filter { $0.displayTitle.localizedCaseInsensitiveContains(searchText) }
    }

    private var isSegmentDataEmpty: Bool {
        segment == .set ? pods.isEmpty : rsvpedFlexMissions.isEmpty
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
                        Picker("", selection: $segment) {
                            ForEach(PodSegment.allCases, id: \.self) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search pods", text: $searchText)
                        }
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                        if isSegmentDataEmpty {
                            VStack(spacing: 12) {
                                Spacer()
                                Image(systemName: segment == .set ? "calendar" : "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 36))
                                    .foregroundStyle(OrbitTheme.gradient)
                                Text(segment == .set ? "no set pods yet" : "no flex pods yet")
                                    .font(.headline)
                                Text("join a mission to form a pod")
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
                                    if segment == .set {
                                        if sortedPods.isEmpty {
                                            Text("no matches")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .padding(.top, 40)
                                        }
                                        ForEach(sortedPods) { pod in
                                            PodRowCard(
                                                pod: pod,
                                                title: pod.displayName,
                                                onDismiss: { Task { await loadData() } },
                                                onPodNotFound: { pods.removeAll { $0.id == pod.id } }
                                            )
                                            .padding(.horizontal, 20)
                                        }
                                    } else {
                                        if filteredFlexMissions.isEmpty {
                                            Text("no matches")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .padding(.top, 40)
                                        }
                                        ForEach(filteredFlexMissions) { mission in
                                            FlexMissionRsvpCard(
                                                mission: mission,
                                                onDismiss: { Task { await loadData() } },
                                                onPodNotFound: { rsvpedFlexMissions.removeAll { $0.id == mission.id } }
                                            )
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
                            showRecommendations = true
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.system(size: 18))
                                .fontWeight(.medium)
                                .foregroundStyle(Color.primary)
                                .padding(4)
                            if !recommendedMissions.isEmpty {
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
        .sheet(isPresented: $showRecommendations) {
            RecommendationsSheet(
                items: recommendedMissions.map { .recommendedMission($0) },
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
        if let newPods = await podsResult {
            pods = newPods
        }
        if let newMissions = await rsvpsResult {
            rsvpedFlexMissions = newMissions
        }
        isLoading = false
    }
}

// MARK: - Pod Row Card

struct PodRowCard: View {
    let pod: Pod
    let title: String
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
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Image(systemName: "person.3")
                            .font(.caption2)
                        Text("\(pod.memberIds.count) members")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

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

                Image(systemName: "message.fill")
                    .foregroundStyle(OrbitTheme.gradient)
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
                        Image(systemName: mission.activityCategory?.icon ?? "star.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text(mission.displayTitle)
                            .font(.headline)
                            .foregroundColor(.white)
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

                Image(systemName: mission.podId != nil ? "message.fill" : "antenna.radiowaves.left.and.right")
                    .foregroundColor(.white.opacity(0.5))
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
        if isActivityCompleted { return "activity completed ✓" }
        switch status {
        case "open": return "forming"
        case "full": return "full"
        case "meeting_confirmed": return "meeting set ✓"
        case "completed": return "completed"
        default: return status
        }
    }

    var color: Color {
        if hasPendingSurvey { return .green }
        if isActivityCompleted { return .secondary }
        switch status {
        case "open": return .orange
        case "full": return OrbitTheme.blue
        case "meeting_confirmed": return .green
        case "completed": return .secondary
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
