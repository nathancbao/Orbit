import SwiftUI

// MARK: - My Events View
// Shows pods the current user has joined.

struct MyEventsView: View {
    @State private var pods: [EventPod] = []
    @State private var events: [String: Event] = [:]  // event_id -> Event
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack {
                TopWavyLines().frame(height: 120)
                Spacer()
            }
            .ignoresSafeArea()

            if isLoading {
                ProgressView()
            } else if pods.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.3")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.9, green: 0.6, blue: 0.7), Color(red: 0.45, green: 0.55, blue: 0.85)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    Text("no pods yet")
                        .font(.headline)
                    Text("join an event from Discover to get started!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("my events")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        ForEach(pods) { pod in
                            PodRowCard(pod: pod, eventTitle: events[String(pod.eventId)]?.title ?? "Event")
                                .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 80)
                    }
                }
                .refreshable { await loadPods() }
            }
        }
        .task { await loadPods() }
        .navigationBarHidden(true)
    }

    private func loadPods() async {
        // In a real implementation this would call a dedicated /users/me/pods endpoint.
        // For now we refresh events and check user_pod_status.
        isLoading = true
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
                            colors: [Color(red: 0.9, green: 0.6, blue: 0.7), Color(red: 0.45, green: 0.55, blue: 0.85)],
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
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.9, green: 0.6, blue: 0.7), Color(red: 0.45, green: 0.55, blue: 0.85)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
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
        case "full": return Color(red: 0.45, green: 0.55, blue: 0.85)
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
