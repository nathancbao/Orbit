import SwiftUI

// MARK: - Signal Status Badge

struct SignalStatusBadge: View {
    let status: SignalStatus

    var body: some View {
        Text(status.label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
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
    @State private var mission: Mission
    let onJoined: () -> Void
    var viewModel: MissionsViewModel?

    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var showSignedUp = false
    @State private var localToast = false
    @State private var joinedPodId: String?
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var showPodSheet = false
    @State private var selectedPodId: String?

    // Member profiles
    @State private var podMembers: [PodMember] = []
    @State private var selectedMemberForPreview: PodMember?
    @State private var selectedMember: (profile: Profile, userId: Int)?

    @Environment(\.dismiss) private var dismiss

    private var isCreator: Bool {
        let uid = UserDefaults.standard.integer(forKey: "orbit_user_id")
        guard uid != 0, mission.creatorId == uid else { return false }
        // Only allow editing for user-created missions (not seeded or AI-suggested)
        if let type = mission.creatorType, type != "user" { return false }
        return true
    }

    init(mission: Mission, viewModel: MissionsViewModel? = nil, onJoined: @escaping () -> Void) {
        self._mission = State(initialValue: mission)
        self.viewModel = viewModel
        self.onJoined = onJoined
    }

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
                ToolbarItem(placement: .navigationBarLeading) {
                    if isCreator, viewModel != nil {
                        Menu {
                            Button {
                                showEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                Label("Delete Mission", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let vm = viewModel {
                MissionCreateView(
                    viewModel: vm,
                    editingMission: mission,
                    onUpdated: { updated in
                        mission = updated
                    }
                )
            }
        }
        .alert("Delete Mission?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    if let vm = viewModel {
                        if mission.isFlexMode {
                            await vm.deleteFlexMission(id: mission.id)
                        } else {
                            await vm.deleteSetMission(id: mission.id)
                        }
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the mission. This action cannot be undone.")
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
            // Fetch full mission detail so pods are always populated
            // (list endpoints don't include pod summaries).
            await fetchFullMissionDetail()
            await fetchPodMembers()
            // For flex missions where user RSVP'd but pod_id was lost, resolve it
            if mission.isFlexMode && !showSignedUp {
                await resolvePodId()
                if joinedPodId != nil {
                    showSignedUp = true
                }
            }
        }
        .sheet(isPresented: $showPodSheet) {
            if let podId = mission.userPodId ?? joinedPodId {
                PodView(podId: podId, title: mission.isFlexMode ? mission.displayTitle : mission.title, missionMode: mission.mode)
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

                MissionPodStatusSection(
                    mission: mission,
                    selectedPodId: $selectedPodId,
                    selectable: mission.userPodStatus != "in_pod" && !mission.isCompleted
                )

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
                    Label("Open Pod", systemImage: "person.3.fill")
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
                    Label("Open Pod", systemImage: "person.3.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(OrbitTheme.gradientFill)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
        } else {
            Button(action: joinSetMission) {
                ZStack {
                    if isJoining {
                        ProgressView().tint(.white)
                    } else {
                        Text("Join Pod \u{2192}")
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
                Label("Open Pod", systemImage: "person.3.fill")
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
                        Text("Join Pod \u{2192}")
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
                            Text("Availability")
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
                let pod = try await MissionService.shared.joinMission(id: mission.id, podId: selectedPodId)
                await MainActor.run {
                    isJoining = false
                    mission.userPodStatus = "in_pod"
                    mission.userPodId = pod.id
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

    /// Fetch the mission fresh to resolve the pod_id when it's missing.
    private func resolvePodId() async {
        do {
            let fetched = try await MissionService.shared.getFlexMission(id: mission.id)
            await MainActor.run {
                if let podId = fetched.podId {
                    joinedPodId = podId
                }
            }
        } catch {
            // Best effort — user can still see the mission
        }
    }

    /// Open the flex pod — resolves pod_id first if needed.
    private func openFlexPod() {
        if joinedPodId != nil {
            showPodSheet = true
            return
        }
        // pod_id missing — fetch it, then open
        Task {
            await resolvePodId()
            await MainActor.run {
                if joinedPodId != nil {
                    showPodSheet = true
                } else {
                    errorMessage = "Could not find your pod. Try again."
                }
            }
        }
    }

    private func openPod(podId: String) {
        showPodSheet = true
    }

    // MARK: - Full Detail Fetch

    private func fetchFullMissionDetail() async {
        do {
            let detailed: Mission
            if mission.isFlexMode {
                detailed = try await MissionService.shared.getFlexMission(id: mission.id)
            } else {
                detailed = try await MissionService.shared.getMission(id: mission.id)
            }
            // Merge pods and pod-status fields into local state
            if let pods = detailed.pods, !pods.isEmpty {
                mission.pods = pods
            }
            if let status = detailed.userPodStatus {
                mission.userPodStatus = status
            }
            if let podId = detailed.userPodId {
                mission.userPodId = podId
            }
        } catch {
            // Non-fatal – the view still works with whatever data it already has.
            print("[MissionDetail] Failed to fetch full detail: \(error)")
        }
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
                Text("Members")
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
// Shown as a sheet when user taps a flex mission (e.g., from Discovery).
// Displays full flex mission info.

struct SignalDetailView: View {
    let mission: Mission
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
                                Image(systemName: mission.activityCategory?.icon ?? "star.fill")
                                    .font(.title)
                                    .foregroundStyle(OrbitTheme.gradient)

                                Text(mission.displayTitle)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                            }
                            .padding(.top, 8)

                            // Category and Status
                            HStack(spacing: 16) {
                                if let category = mission.activityCategory {
                                    HStack(spacing: 6) {
                                        Image(systemName: "tag")
                                            .foregroundStyle(OrbitTheme.gradient)
                                        Text(category.displayName)
                                            .font(.subheadline)
                                    }
                                }

                                if let status = mission.signalStatus {
                                    SignalStatusBadge(status: status)
                                }
                            }
                            .foregroundColor(.secondary)

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
                                    Text("Availability")
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

                            Spacer(minLength: 80)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }

                    // Action button area
                    if showSignedUp, joinedPodId != nil {
                        Button(action: { showPod = true }) {
                            Label("Open Pod", systemImage: "person.3.fill")
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
                            joinFlexMission()
                        } label: {
                            ZStack {
                                if isRsvping {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Join Pod \u{2192}")
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
                    PodView(podId: podId, title: mission.displayTitle, missionMode: .flex)
                }
            }
            .onAppear {
                // If the mission already has a pod_id, user already RSVP'd
                if let podId = mission.podId {
                    showSignedUp = true
                    joinedPodId = podId
                }
            }
        }
    }

    private func joinFlexMission() {
        isRsvping = true
        rsvpError = nil
        Task {
            do {
                let updated = try await MissionService.shared.joinFlexMission(id: mission.id)
                await MainActor.run {
                    isRsvping = false
                    showSignedUp = true
                    joinedPodId = updated.podId
                    withAnimation(.spring(duration: 0.3)) { localToast = true }
                    // If we got a pod, don't auto-dismiss — let user open the pod
                    if updated.podId == nil {
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
                        joinedPodId = mission.podId
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
    @Binding var selectedPodId: String?
    let selectable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pods")
                .font(.headline)

            if selectable && (mission.pods?.count ?? 0) > 1 {
                Text("Tap a Pod to choose where to join")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let pods = mission.pods, !pods.isEmpty {
                ForEach(pods, id: \.podId) { pod in
                    let effectiveMaxSize = max(pod.maxSize, mission.maxPodSize)
                    let effectiveSpotsLeft = max(0, effectiveMaxSize - pod.memberCount)
                    let isOpen = pod.status != "full" && effectiveSpotsLeft > 0
                    let isSelected = selectedPodId == pod.podId

                    HStack {
                        Image(systemName: isOpen ? "circle.dotted" : "circle.fill")
                            .foregroundColor(isSelected ? OrbitTheme.purple : (isOpen ? .green : .secondary))
                            .font(.caption)
                        Text("Pod · \(pod.memberCount)/\(effectiveMaxSize) members")
                            .font(.subheadline)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(OrbitTheme.gradient)
                                .font(.subheadline)
                        }
                        Text(isOpen ? "\(effectiveSpotsLeft) spots left" : "full")
                            .font(.caption)
                            .foregroundColor(isOpen ? .green : .secondary)
                    }
                    .padding(12)
                    .background(isSelected ? OrbitTheme.purple.opacity(0.08) : Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? OrbitTheme.purple : Color.clear, lineWidth: 1.5)
                    )
                    .onTapGesture {
                        guard selectable && isOpen else { return }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedPodId = isSelected ? nil : pod.podId
                        }
                    }
                    .opacity(selectable && !isOpen ? 0.5 : 1)
                }
            } else {
                Text("No Pods yet — be the first to join!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
