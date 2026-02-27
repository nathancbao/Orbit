import SwiftUI

// MARK: - Pods View
// Unified list of all pods the user has joined (missions + signals).

struct PodsView: View {
    @Binding var userProfile: Profile
    @State private var pods: [EventPod] = []
    @State private var isLoading = false
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(OrbitTheme.purple)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if pods.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundStyle(OrbitTheme.gradient)
                        Text("no pods yet")
                            .font(.headline)
                        Text("join a mission or respond to a signal to form a pod")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(pods) { pod in
                                PodRowCard(pod: pod, eventTitle: "Mission")
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 80)
                    }
                    .refreshable { await loadPods() }
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
        .task { await loadPods() }
    }

    private func loadPods() async {
        isLoading = true
        // TODO: call /users/me/pods endpoint when available
        try? await Task.sleep(for: .milliseconds(300))
        isLoading = false
    }
}

// MARK: - Pod Row Card

struct PodRowCard: View {
    let pod: EventPod
    let eventTitle: String
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
                    Text(eventTitle)
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
        .sheet(isPresented: $showPod) {
            PodView(podId: pod.id, eventTitle: eventTitle)
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
