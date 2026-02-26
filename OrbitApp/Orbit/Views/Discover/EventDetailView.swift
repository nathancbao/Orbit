import SwiftUI

// MARK: - Mission Detail View
// Shown as a sheet when user taps a mission card.
// Displays full mission info and "Join Pod" button.

struct MissionDetailView: View {
    let mission: Mission
    let onJoined: () -> Void

    @State private var isJoining = false
    @State private var joinedPod: EventPod?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack {
                    Spacer()
                    BottomWavyLines().frame(height: 150)
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Title
                        Text(mission.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.top, 8)

                        // Meta row
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .foregroundStyle(OrbitTheme.gradient)
                                Text(mission.displayDate)
                                    .font(.subheadline)
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(OrbitTheme.gradient)
                                Text(mission.location.isEmpty ? "Location TBD" : mission.location)
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }
                        }
                        .foregroundColor(.secondary)

                        // Tags
                        if !mission.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(mission.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(OrbitTheme.blue.opacity(0.12))
                                            .clipShape(Capsule())
                                            .foregroundColor(OrbitTheme.blue)
                                    }
                                }
                            }
                        }

                        // Description
                        Text(mission.description)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(4)

                        Divider()

                        // Pod status section
                        MissionPodStatusSection(mission: mission)

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        // Action button
                        actionButton

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(item: $joinedPod) { pod in
            PodView(podId: pod.id, eventTitle: mission.title)
                .onDisappear {
                    onJoined()
                    dismiss()
                }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch mission.userPodStatus {
        case "in_pod":
            if let podId = mission.userPodId {
                Button(action: { openPod(podId: podId) }) {
                    Label("open your pod", systemImage: "person.3.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(OrbitTheme.gradientFill)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
        case "pod_full":
            Text("all pods are currently full")
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.secondary)
                .font(.subheadline)
        default:
            Button(action: join) {
                ZStack {
                    if isJoining {
                        ProgressView().tint(.white)
                    } else {
                        Text("join a pod →")
                            .font(.system(size: 16, weight: .semibold))
                            .tracking(0.5)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(OrbitTheme.gradientFill)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .disabled(isJoining)
        }
    }

    private func join() {
        isJoining = true
        errorMessage = nil
        Task {
            do {
                let pod = try await MissionService.shared.joinMission(id: mission.id)
                await MainActor.run {
                    isJoining = false
                    joinedPod = pod
                }
            } catch {
                await MainActor.run {
                    isJoining = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func openPod(podId: String) {
        Task {
            let pod = try? await PodService.shared.getPod(id: podId)
            await MainActor.run {
                joinedPod = pod
            }
        }
    }
}

// MARK: - Mission Pod Status Section

struct MissionPodStatusSection: View {
    let mission: Mission

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("pods")
                .font(.headline)

            if let pods = mission.pods, !pods.isEmpty {
                ForEach(pods, id: \.podId) { pod in
                    HStack {
                        Image(systemName: pod.status == "open" ? "circle.dotted" : "circle.fill")
                            .foregroundColor(pod.status == "open" ? .green : .secondary)
                            .font(.caption)
                        Text("Pod · \(pod.memberCount)/\(pod.maxSize) members")
                            .font(.subheadline)
                        Spacer()
                        Text(pod.status == "open" ? "\(pod.spotsLeft) spots left" : "full")
                            .font(.caption)
                            .foregroundColor(pod.status == "open" ? .green : .secondary)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            } else {
                Text("no pods yet — be the first to join!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
