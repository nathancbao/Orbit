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
    @State private var rsvpedSignals: [Signal] = []
    @State private var isLoading = false
    @State private var showProfile = false
    @State private var showShareSheet = false

    private var currentUserId: Int {
        UserDefaults.standard.integer(forKey: "orbit_user_id")
    }
    @State private var segment: PodSegment = .set
    @State private var searchText = ""

    private var isEmpty: Bool { pods.isEmpty && rsvpedSignals.isEmpty }

    /// Set pods sorted by scheduled time (soonest first), filtered by search.
    private var sortedPods: [Pod] {
        let sorted = pods.sorted { a, b in
            let dateA = a.parsedScheduledTime ?? .distantFuture
            let dateB = b.parsedScheduledTime ?? .distantFuture
            return dateA < dateB
        }
        if searchText.isEmpty { return sorted }
        return sorted.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    /// Flex signals filtered by search.
    private var filteredSignals: [Signal] {
        if searchText.isEmpty { return rsvpedSignals }
        return rsvpedSignals.filter { $0.displayTitle.localizedCaseInsensitiveContains(searchText) }
    }

    private var isSegmentDataEmpty: Bool {
        segment == .set ? pods.isEmpty : rsvpedSignals.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if isLoading && pods.isEmpty && rsvpedSignals.isEmpty {
                    ProgressView()
                        .tint(OrbitTheme.purple)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundStyle(OrbitTheme.gradient)
                        Text("no pods yet")
                            .font(.headline)
                        Text("join a mission to form a pod")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
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
                                    .foregroundColor(.secondary)
                                Text(segment == .set ? "no set pods yet" : "no flex pods yet")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
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
                                            PodRowCard(pod: pod, title: pod.displayName) {
                                                Task { await loadData() }
                                            }
                                            .padding(.horizontal, 20)
                                        }
                                    } else {
                                        if filteredSignals.isEmpty {
                                            Text("no matches")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .padding(.top, 40)
                                        }
                                        ForEach(filteredSignals) { signal in
                                            SignalRsvpCard(signal: signal) {
                                                Task { await loadData() }
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
                    Button { } label: {
                        Image(systemName: "bell")
                            .font(.system(size: 18))
                            .fontWeight(.medium)
                            .foregroundStyle(Color.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button { showShareSheet = true } label: {
                            Image(systemName: "qrcode")
                                .font(.system(size: 18))
                                .fontWeight(.medium)
                                .foregroundStyle(Color.primary)
                        }
                        Button { showProfile = true } label: {
                            ProfileAvatarView(photo: userProfile.photo, size: 34, name: userProfile.name)
                        }
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
        .sheet(isPresented: $showShareSheet) {
            FriendShareView(userId: currentUserId, userName: userProfile.name)
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
        async let rsvpsResult: [Signal]? = try? APIService.shared.request(
            endpoint: Constants.API.Endpoints.myRsvps,
            authenticated: true
        )
        if let newPods = await podsResult {
            pods = newPods
        }
        if let newSignals = await rsvpsResult {
            rsvpedSignals = newSignals
        }
        isLoading = false
    }
}

// MARK: - Pod Row Card

struct PodRowCard: View {
    let pod: Pod
    let title: String
    var onDismiss: (() -> Void)? = nil
    @State private var showPod = false

    var body: some View {
        Button(action: { showPod = true }) {
            HStack(spacing: 14) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [OrbitTheme.pink, OrbitTheme.blue],
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

                    if let time = pod.scheduledTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(time)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }

                    PodStatusBadge(status: pod.status)
                }

                Spacer()

                Image(systemName: "message.fill")
                    .foregroundStyle(OrbitTheme.gradient)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPod, onDismiss: {
            onDismiss?()
        }) {
            PodView(podId: pod.id, title: title)
        }
    }
}

// MARK: - Signal RSVP Card (Black Theme)

struct SignalRsvpCard: View {
    let signal: Signal
    var onDismiss: (() -> Void)? = nil
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
                        Image(systemName: signal.activityCategory.icon)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text(signal.displayTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text(signal.groupSizeLabel)
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.6))

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(signal.availabilitySummary)
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.6))

                    SignalStatusBadgeDark(status: signal.status)
                }

                Spacer()

                Image(systemName: signal.podId != nil ? "message.fill" : "antenna.radiowaves.left.and.right")
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
            if let podId = signal.podId {
                PodView(podId: podId, title: signal.displayTitle, missionMode: .flex)
            } else {
                SignalDetailView(signal: signal)
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

    var label: String {
        switch status {
        case "open": return "forming"
        case "full": return "full"
        case "meeting_confirmed": return "meeting set ✓"
        case "completed": return "completed"
        default: return status
        }
    }

    var color: Color {
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
