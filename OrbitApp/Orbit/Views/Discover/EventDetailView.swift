import SwiftUI

// MARK: - Mission Detail View
// Shown as a sheet when user taps a mission card.
// Displays full mission info and "Join Pod" button.

struct MissionDetailView: View {
    let mission: Mission
    let onJoined: () -> Void

    @State private var isJoining = false
    @State private var joinedPod: Pod?
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
            PodView(podId: pod.id, title: mission.title)
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

// MARK: - Signal Detail View
// Shown as a sheet when user taps a signal (e.g., from Discovery).
// Displays full signal info.

struct SignalDetailView: View {
    let signal: Signal
    var viewModel: SignalsViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var showSignedUp = false
    @State private var localToast = false
    @State private var isRsvping = false
    @State private var rsvpError: String?
    @State private var joinedPodId: String?
    @State private var showPod = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack {
                    Spacer()
                    BottomWavyLines().frame(height: 150)
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {

                            // Icon and Title
                            HStack(spacing: 12) {
                                Image(systemName: signal.activityCategory.icon)
                                    .font(.title)
                                    .foregroundStyle(OrbitTheme.gradient)

                                Text(signal.displayTitle)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                            }
                            .padding(.top, 8)

                            // Category and Status
                            HStack(spacing: 16) {
                                HStack(spacing: 6) {
                                    Image(systemName: "tag")
                                        .foregroundStyle(OrbitTheme.gradient)
                                    Text(signal.activityCategory.displayName)
                                        .font(.subheadline)
                                }

                                SignalStatusBadge(status: signal.status)
                            }
                            .foregroundColor(.secondary)

                            // Group Size
                            HStack(spacing: 6) {
                                Image(systemName: "person.2.fill")
                                    .foregroundStyle(OrbitTheme.gradient)
                                Text(signal.groupSizeLabel)
                                    .font(.subheadline)
                            }
                            .foregroundColor(.secondary)

                            // Description
                            if !signal.description.isEmpty {
                                Text(signal.description)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineSpacing(4)
                            }

                            // Links
                            if let links = signal.links, !links.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(links, id: \.self) { link in
                                        if let url = URL(string: link) {
                                            Button {
                                                UIApplication.shared.open(url)
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "link")
                                                        .font(.caption)
                                                    Text(link)
                                                        .font(.subheadline)
                                                        .lineLimit(1)
                                                        .truncationMode(.middle)
                                                }
                                                .foregroundColor(OrbitTheme.blue)
                                            }
                                        }
                                    }
                                }
                            }

                            Divider()

                            // Availability Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("availability")
                                    .font(.headline)

                                Text(signal.availabilitySummary)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if !signal.availability.isEmpty {
                                    ForEach(signal.availability) { slot in
                                        HStack(spacing: 10) {
                                            Text(slot.dayLabel)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .frame(width: 70, alignment: .leading)

                                            ForEach(slot.timeBlocks, id: \.self) { block in
                                                HStack(spacing: 4) {
                                                    Image(systemName: block.icon)
                                                        .font(.caption2)
                                                    Text(block.label)
                                                        .font(.caption)
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(OrbitTheme.purple.opacity(0.12))
                                                .clipShape(Capsule())
                                                .foregroundColor(OrbitTheme.purple)
                                            }
                                        }
                                        .padding(12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                }
                            }

                            Spacer(minLength: 80)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }

                    // Action button area
                    if showSignedUp {
                        if joinedPodId != nil {
                            // Open pod button (like Missions)
                            Button(action: { showPod = true }) {
                                Label("open your pod", systemImage: "person.3.fill")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(OrbitTheme.gradientFill)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                        } else {
                            // Fallback when backend hasn't added pod_id yet
                            Text("You already signed up for this event!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 16)
                        }
                    } else {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            rsvpSignal()
                        } label: {
                            ZStack {
                                if isRsvping {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("I'm Down")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(OrbitTheme.gradientFill)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isRsvping)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                        if let error = rsvpError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if localToast {
                    Text("You're in!")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(Capsule().fill(Color(red: 0.1, green: 0.1, blue: 0.22).opacity(0.95)))
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: localToast)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPod) {
                if let podId = joinedPodId {
                    PodView(podId: podId, title: signal.displayTitle)
                }
            }
            .onAppear {
                // If the signal already has a pod_id, user already RSVP'd
                if let podId = signal.podId {
                    showSignedUp = true
                    joinedPodId = podId
                }
            }
        }
    }

    private func rsvpSignal() {
        isRsvping = true
        rsvpError = nil
        Task {
            do {
                let rsvpedSignal = try await SignalService.shared.rsvpSignal(id: signal.id)
                await MainActor.run {
                    isRsvping = false
                    showSignedUp = true
                    joinedPodId = rsvpedSignal.podId
                    if let viewModel {
                        viewModel.showToastMessage("You're in!")
                    } else {
                        withAnimation(.spring(duration: 0.3)) { localToast = true }
                    }
                    // If we got a pod, don't auto-dismiss — let user open the pod
                    if rsvpedSignal.podId == nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
                    }
                }
            } catch {
                await MainActor.run {
                    isRsvping = false
                    let message = error.localizedDescription
                    if message.localizedCaseInsensitiveContains("already") {
                        // User already RSVP'd — treat as success
                        showSignedUp = true
                        joinedPodId = signal.podId
                    } else {
                        rsvpError = message
                    }
                }
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
