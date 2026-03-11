import SwiftUI

// MARK: - Wrapped Hour (Identifiable wrapper for ForEach)

struct WrappedHour: Identifiable {
    let hour: Int
    var id: Int { hour }
}

// MARK: - Flow Layout (wrapping horizontal layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Mission Detail View
// Shown as a sheet when user taps a mission card.
// Displays full mission info and "Join Pod" button.

struct MissionDetailView: View {
    let mission: Mission
    let onJoined: () -> Void

    @State private var isJoining = false
    @State private var joinedPod: Pod?
    @State private var errorMessage: String?
    @State private var showSignedUp = false
    @State private var localToast = false
    @State private var joinedPodId: String?
    @State private var showPod = false

    // Member profiles
    @State private var podMembers: [PodMember] = []
    @State private var selectedMemberForPreview: PodMember?
    @State private var selectedMember: (profile: Profile, userId: Int)?

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

                if mission.isFlexMode {
                    flexContent
                } else {
                    setContent
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
        }
        .fullScreenCover(item: $joinedPod) { pod in
            PodView(podId: pod.id, title: mission.isFlexMode ? mission.displayTitle : mission.title, missionMode: mission.mode)
                .onDisappear {
                    onJoined()
                    dismiss()
                }
        }
        .fullScreenCover(isPresented: $showPod) {
            if let podId = joinedPodId {
                PodView(podId: podId, title: mission.displayTitle, missionMode: mission.mode)
            }
        }
        .sheet(item: $selectedMemberForPreview) { member in
            MemberPreviewSheet(member: member)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: Binding(
            get: { selectedMember != nil },
            set: { if !$0 { selectedMember = nil } }
        )) {
            if let member = selectedMember {
                ProfileDisplayView(profile: member.profile, otherUserId: member.userId)
            }
        }
        .onAppear {
            if mission.isFlexMode {
                let resolvedPodId = mission.userPodId ?? mission.podId ?? mission.pods?.first?.podId
                if let podId = resolvedPodId {
                    showSignedUp = true
                    joinedPodId = podId
                }
            }
        }
        .task {
            await fetchPodMembers()
            // For flex missions where user RSVP'd but pod_id was lost, resolve it
            if mission.isFlexMode && !showSignedUp {
                await resolvePodId()
                if joinedPodId != nil {
                    showSignedUp = true
                }
            }
        }
    }

    // MARK: - Set Mode Content (unchanged)

    private var setContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(mission.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)

                if mission.isCompleted {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "059669"))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mission completed!")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if let countdown = mission.deletionCountdownString {
                                Text("Mission will be deleted in \(countdown)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("This mission will be removed shortly.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color(hex: "059669").opacity(0.08))
                    .cornerRadius(12)
                }

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

                Text(mission.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(4)

                Divider()

                MissionPodStatusSection(mission: mission)

                if !podMembers.isEmpty {
                    MissionMemberSection(
                        members: podMembers,
                        isInPod: isInPod,
                        onTapMember: handleMemberTap
                    )
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                setActionButton

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var setActionButton: some View {
        if mission.isCompleted {
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
        } else if mission.userPodStatus == "in_pod" {
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
        } else if mission.userPodStatus == "pod_full" {
            Text("all pods are currently full")
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.secondary)
                .font(.subheadline)
        } else {
            Button(action: joinSetMission) {
                ZStack {
                    if isJoining {
                        ProgressView().tint(.white)
                    } else {
                        Text("join a pod \u{2192}")
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

    @ViewBuilder
    private var flexActionButton: some View {
        if showSignedUp {
            Button(action: { openFlexPod() }) {
                Label("open your pod", systemImage: "person.3.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(OrbitTheme.gradientFill)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                joinFlexMission()
            } label: {
                ZStack {
                    if isJoining {
                        ProgressView().tint(.white)
                    } else {
                        Text("join a pod \u{2192}")
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
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Flex Mode Content

    private var flexContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text(mission.displayTitle)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 8)

                    // Status
                    if let status = mission.signalStatus {
                        FlexStatusBadge(status: status)
                    }

                    // Group Size
                    if let label = mission.flexGroupSizeLabel {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(OrbitTheme.gradient)
                            Text(label)
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }

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
                    if !mission.description.isEmpty {
                        Text(mission.description)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                    }

                    // Links
                    if let links = mission.links, !links.isEmpty {
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
                    if let slots = mission.availability, !slots.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("availability")
                                .font(.headline)

                            if let summary = mission.flexAvailabilitySummary {
                                Text(summary)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            ForEach(slots) { slot in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(slot.dayLabel)
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    if slot.isHourly {
                                        let wrapped = slot.hours.map { WrappedHour(hour: $0) }
                                        FlowLayout(spacing: 6) {
                                            ForEach(wrapped) { wh in
                                                Text(hourString(wh.hour))
                                                    .font(.caption)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 5)
                                                    .background(OrbitTheme.purple.opacity(0.12))
                                                    .clipShape(Capsule())
                                                    .foregroundColor(OrbitTheme.purple)
                                            }
                                        }
                                    } else {
                                        HStack(spacing: 6) {
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
                                    }
                                }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }

                    if !podMembers.isEmpty {
                        MissionMemberSection(
                            members: podMembers,
                            isInPod: isInPod,
                            onTapMember: handleMemberTap
                        )
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            // Flex action button area
            flexActionButton

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Actions

    private func joinSetMission() {
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

    private func joinFlexMission() {
        isJoining = true
        errorMessage = nil
        Task {
            do {
                let updated = try await MissionService.shared.joinFlexMission(id: mission.id)
                await MainActor.run {
                    isJoining = false
                    showSignedUp = true
                    joinedPodId = updated.podId
                    withAnimation(.spring(duration: 0.3)) { localToast = true }
                }
                // If pod_id missing from response, fetch signal fresh to resolve it
                if updated.podId == nil {
                    await resolvePodId()
                }
            } catch {
                await MainActor.run {
                    isJoining = false
                    let message = error.localizedDescription
                    if message.localizedCaseInsensitiveContains("already") {
                        showSignedUp = true
                        joinedPodId = mission.podId
                    } else {
                        errorMessage = message
                    }
                }
                // If already RSVP'd but pod_id unknown, fetch it
                if joinedPodId == nil && showSignedUp {
                    await resolvePodId()
                }
            }
        }
    }

    /// Fetch the signal fresh to resolve the pod_id when it's missing.
    private func resolvePodId() async {
        do {
            let signal = try await SignalService.shared.getSignal(id: mission.id)
            await MainActor.run {
                if let podId = signal.podId {
                    joinedPodId = podId
                }
            }
        } catch {
            // Best effort — user can still see the mission
        }
    }

    /// Open the flex pod — resolves pod_id first if needed.
    private func openFlexPod() {
        if let podId = joinedPodId {
            showPod = true
            return
        }
        // pod_id missing — fetch it, then open
        Task {
            await resolvePodId()
            await MainActor.run {
                if joinedPodId != nil {
                    showPod = true
                } else {
                    errorMessage = "Could not find your pod. Try again."
                }
            }
        }
    }

    private func openPod(podId: String) {
        joinedPodId = podId
        showPod = true
    }

    // MARK: - Member Fetching

    private func fetchPodMembers() async {
        // Unified fallback: user's pod → mission-level podId → first pod from list
        let targetPodId = mission.userPodId ?? mission.podId ?? mission.pods?.first?.podId
        guard let podId = targetPodId else { return }
        if let pod = try? await PodService.shared.getPod(id: podId) {
            podMembers = pod.members ?? []
        }
    }

    private var isInPod: Bool {
        mission.userPodStatus == "in_pod"
    }

    private func handleMemberTap(_ member: PodMember) {
        if isInPod {
            // Full profile for pod members
            let uid = member.userId
            Task {
                if let profile = try? await ProfileService.shared.getUserProfile(id: uid) {
                    selectedMember = (profile: profile, userId: uid)
                }
            }
        } else {
            // Limited preview for non-members
            selectedMemberForPreview = member
        }
    }
}

// MARK: - Mission Member Section

struct MissionMemberSection: View {
    let members: [PodMember]
    let isInPod: Bool
    let onTapMember: (PodMember) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("members")
                    .font(.headline)
                Spacer()
                Text("\(members.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if members.isEmpty {
                Text("No members yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(members) { member in
                            Button { onTapMember(member) } label: {
                                VStack(spacing: 6) {
                                    ProfileAvatarView(photo: member.photo, size: 44)
                                    Text(member.name.components(separatedBy: " ").first ?? member.name)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    if !member.collegeYear.isEmpty {
                                        Text(member.collegeYear)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Member Preview Sheet (limited profile for non-pod browsers)

struct MemberPreviewSheet: View {
    let member: PodMember

    var body: some View {
        VStack(spacing: 20) {
            ProfileAvatarView(photo: member.photo, size: 80)

            Text(member.name)
                .font(.title2)
                .fontWeight(.bold)

            if !member.collegeYear.isEmpty {
                Text(member.collegeYear)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if !member.interests.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(member.interests, id: \.self) { interest in
                        Text(interest)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(OrbitTheme.purple.opacity(0.12))
                            .clipShape(Capsule())
                            .foregroundColor(OrbitTheme.purple)
                    }
                }
            }

            Spacer()
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
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
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(slot.dayLabel)
                                                .font(.subheadline)
                                                .fontWeight(.medium)

                                            if slot.isHourly {
                                                // New hourly format
                                                let wrapped = slot.hours.map { WrappedHour(hour: $0) }
                                                FlowLayout(spacing: 6) {
                                                    ForEach(wrapped) { wh in
                                                        Text(hourString(wh.hour))
                                                            .font(.caption)
                                                            .padding(.horizontal, 10)
                                                            .padding(.vertical, 5)
                                                            .background(OrbitTheme.purple.opacity(0.12))
                                                            .clipShape(Capsule())
                                                            .foregroundColor(OrbitTheme.purple)
                                                    }
                                                }
                                            } else {
                                                // Legacy time-block format
                                                HStack(spacing: 6) {
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
                    if showSignedUp, joinedPodId != nil {
                        Button(action: { showPod = true }) {
                            Label("open your pod", systemImage: "person.3.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .tracking(0.5)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(OrbitTheme.gradientFill)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    } else if showSignedUp {
                        Text("You're signed up — waiting for a pod")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                    } else {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            rsvpSignal()
                        } label: {
                            ZStack {
                                if isRsvping {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("join a pod \u{2192}")
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
                    PodView(podId: podId, title: signal.displayTitle, missionMode: .flex)
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
