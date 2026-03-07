import SwiftUI

// MARK: - Pods View
// Unified list of all pods the user has joined (missions + signals).

struct PodsView: View {
    @Binding var userProfile: Profile
    var isActive: Bool = false
    @State private var pods: [Pod] = []
    @State private var rsvpedSignals: [Signal] = []
    @State private var isLoading = false
    @State private var showProfile = false

    private var isEmpty: Bool { pods.isEmpty && rsvpedSignals.isEmpty }

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
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(pods) { pod in
                                PodRowCard(pod: pod, title: pod.displayName) {
                                    Task { await loadData() }
                                }
                                    .padding(.horizontal, 20)
                            }

                            if !rsvpedSignals.isEmpty {
                                ForEach(rsvpedSignals) { signal in
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
            .navigationTitle("Pods")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { } label: {
                        Image(systemName: "bell")
                            .fontWeight(.medium)
                            .foregroundStyle(Color.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showProfile = true } label: {
                        ProfileAvatarView(photo: userProfile.photo, size: 30, name: userProfile.name)
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
        pods = await podsResult ?? []
        rsvpedSignals = await rsvpsResult ?? []
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
