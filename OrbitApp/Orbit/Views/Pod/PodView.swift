import SwiftUI

// MARK: - Pod View
// Chat screen for a pod. Shows member strip + messages + vote cards + action bar.

struct PodView: View {
    let podId: String
    let title: String
    let missionMode: MissionMode
    var onPodNotFound: (() -> Void)?

    @StateObject private var viewModel: PodViewModel
    @State private var scheduleVM: ScheduleViewModel?
    @State private var showVoteSheet = false
    @State private var voteSheetType: String = "time"
    @State private var showScheduleSheet = false
    @State private var showKickSheet = false
    @State private var kickTarget: PodMember?
    @State private var showEditPodSheet = false
    @State private var showLeaveAlert = false
    @State private var showDeleteAlert = false
    @State private var showInviteSheet = false
    @State private var showMissionSheet = false
    @State private var selectedMember: (profile: Profile, userId: Int)?
    @State private var isLoadingProfile = false
    @Environment(\.dismiss) private var dismiss

    // Retrieve current user id from keychain (simple approach)
    private let currentUserId: Int = {
        // AuthService stores userId in UserDefaults during login
        UserDefaults.standard.integer(forKey: "orbit_user_id")
    }()

    private let currentUserName: String = {
        UserDefaults.standard.string(forKey: "orbit_user_name") ?? "You"
    }()

    private var displayTitle: String {
        viewModel.pod?.name ?? title
    }

    /// Whether the signed-in user is the pod leader (first member in join order).
    private var isLeader: Bool {
        viewModel.pod?.leaderId == currentUserId
    }

    /// Display name for a pod member (falls back to "Someone").
    private func memberName(_ userId: Int) -> String {
        if userId == currentUserId { return "You" }
        return viewModel.pod?.members?.first(where: { $0.userId == userId })?.name ?? "Someone"
    }

    init(podId: String, title: String, missionMode: MissionMode = .set, onPodNotFound: (() -> Void)? = nil) {
        self.podId = podId
        self.title = title
        self.missionMode = missionMode
        self.onPodNotFound = onPodNotFound
        _viewModel = StateObject(wrappedValue: PodViewModel(podId: podId, missionMode: missionMode))
    }

    var body: some View {
        podViewWithSheets
            .onChange(of: viewModel.didLeave) {
                if viewModel.didLeave { dismiss() }
            }
            .onChange(of: viewModel.isLoading) {
                if !viewModel.isLoading {
                    createScheduleVMIfNeeded()
                    scheduleVM?.reloadGrid()
                }
            }
            .onChange(of: viewModel.podNotFound) {
                if viewModel.podNotFound {
                    onPodNotFound?()
                    // Auto-dismiss after a brief delay so user sees the message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
            .overlay {
                if viewModel.podNotFound {
                    ZStack {
                        Color(.systemBackground).ignoresSafeArea()
                        VStack(spacing: 12) {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.secondary)
                            Text("Pod not found. Deleting.")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                    .transition(.opacity)
                } else if viewModel.notAMember {
                    ZStack {
                        Color(.systemBackground).ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "person.fill.xmark")
                                .font(.system(size: 44))
                                .foregroundColor(.secondary)
                            Text("You are not a member of this pod.")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            Text("This pod may have been removed or you were kicked.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Button {
                                Task {
                                    await viewModel.leavePod()
                                    onPodNotFound?()
                                }
                            } label: {
                                Text("Remove from My Pods")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(OrbitTheme.gradientFill)
                                    .clipShape(Capsule())
                            }
                            .disabled(viewModel.isLeaving)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .task {
                await viewModel.load()
                createScheduleVMIfNeeded()
                if missionMode == .flex,
                   let pod = viewModel.pod,
                   pod.scheduleData?.entries[String(currentUserId)] == nil,
                   ScheduleService.shared.existingGrid(podId: podId)?
                       .entries.first(where: { $0.userId == currentUserId })?.hasSubmitted != true {
                    showScheduleSheet = true
                }
            }
    }

    private var podViewWithSheets: some View {
        podViewWithAlerts
            .sheet(isPresented: $showVoteSheet) {
                CreateVoteSheet(
                    voteType: voteSheetType,
                    onCreate: { options in
                        Task { await viewModel.createVote(type: voteSheetType, options: options) }
                        showVoteSheet = false
                    },
                    onCancel: { showVoteSheet = false }
                )
            }
            .sheet(isPresented: Binding(
                get: { selectedMember != nil },
                set: { if !$0 { selectedMember = nil } }
            )) {
                if let member = selectedMember {
                    ProfileDisplayView(
                        profile: member.profile,
                        otherUserId: member.userId != currentUserId ? member.userId : nil
                    )
                }
            }
            .sheet(isPresented: $showInviteSheet) {
                PodInviteSheet(
                    podId: podId,
                    currentMemberIds: viewModel.pod?.memberIds ?? []
                )
            }
            .sheet(isPresented: $showEditPodSheet) {
                EditPodSheet(
                    initialName: viewModel.pod?.name ?? "",
                    initialPlace: viewModel.pod?.scheduledPlace ?? "",
                    onSave: { name, place in
                        Task {
                            await viewModel.editPod(
                                name: name.isEmpty ? nil : name,
                                place: place
                            )
                        }
                    }
                )
            }
            .sheet(isPresented: $showMissionSheet) {
                if let mission = viewModel.mission {
                    MissionDetailView(mission: mission, onJoined: {})
                }
            }
            .sheet(isPresented: $showScheduleSheet) {
                if let pod = viewModel.pod, let svm = scheduleVM {
                    NavigationStack {
                        FlexPodFormingView(pod: pod, scheduleVM: svm, podVM: viewModel)
                            .navigationTitle("Availability")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { showScheduleSheet = false }
                                }
                            }
                    }
                }
            }
    }

    private var podViewWithAlerts: some View {
        NavigationStack {
            mainContent
                .navigationTitle(displayTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        .alert(
            "Kick \(kickTarget?.name ?? "member")?",
            isPresented: $showKickSheet,
            presenting: kickTarget
        ) { member in
            Button("Kick", role: .destructive) {
                Task { await viewModel.kickMember(userId: member.userId) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { member in
            Text("Your vote to kick \(member.name) will be recorded. A majority is needed to remove them.")
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Leave Pod?", isPresented: $showLeaveAlert) {
            Button("Leave", role: .destructive) {
                Task { await viewModel.leavePod() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will no longer be able to see this pod's chat or votes.")
        }
        .alert("Delete Pod?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deletePod() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes the pod for everyone. All members will be notified.")
        }
    }

    // MARK: - Main Content (broken out for type-checker)

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if viewModel.isLoading && viewModel.pod == nil {
                ProgressView()
            } else {
                existingChatContent
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Close") { dismiss() }
        }
        // Only the pod leader can edit the pod (name + meeting place).
        if isLeader {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showEditPodSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .foregroundStyle(OrbitTheme.gradient)
                }
            }
        }
    }

    /// Lazily create ScheduleViewModel for flex mode pods.
    private func createScheduleVMIfNeeded() {
        guard missionMode == .flex, let pod = viewModel.pod, scheduleVM == nil else { return }
        scheduleVM = ScheduleViewModel(
            podId: podId,
            missionId: pod.missionId,
            currentUserId: currentUserId,
            currentUserName: currentUserName
        )
    }

    // MARK: - Existing Chat Content (Set Mode / Post-Scheduling)

    private var existingChatContent: some View {
        VStack(spacing: 0) {
            // Member strip
            if let pod = viewModel.pod, let members = pod.members {
                MemberStripView(
                    members: members,
                    currentUserId: currentUserId,
                    onKick: { member in
                        kickTarget = member
                        showKickSheet = true
                    },
                    onTapMember: { member in
                        loadMemberProfile(userId: member.userId)
                    }
                )
            }

            Divider()

            // Waiting for minimum members banner
            waitingForMembersBanner

            // Confirmed time/place banner (flex pods)
            if missionMode == .flex {
                confirmedDetailsBanner
            }

            // Activity completed banner (set missions after end time)
            activityCompletedBanner

            // Pinned message (leader-pinned, Discord-style)
            pinnedMessageBanner

            // Action bar
            actionBar

            Divider()

            // Chat messages
            chatBody

            // Safety reminder
            Text("Stay safe — meet in public spaces and let a friend know your plans.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 6)

            // Input bar
            inputBar
        }
    }

    private func loadMemberProfile(userId: Int) {
        isLoadingProfile = true
        Task {
            do {
                let profile = try await ProfileService.shared.getUserProfile(id: userId)
                await MainActor.run {
                    isLoadingProfile = false
                    selectedMember = (profile: profile, userId: userId)
                }
            } catch {
                await MainActor.run {
                    isLoadingProfile = false
                }
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Direct link to the mission this pod belongs to.
                if viewModel.mission != nil {
                    ActionChip(icon: "scope", label: "Mission") {
                        showMissionSheet = true
                    }
                }
                if missionMode == .flex {
                    ActionChip(icon: "calendar.badge.plus", label: "Availability") {
                        showScheduleSheet = true
                    }
                    ActionChip(icon: "clock", label: "Vote time") {
                        voteSheetType = "time"
                        showVoteSheet = true
                    }
                    ActionChip(icon: "mappin", label: "Vote place") {
                        voteSheetType = "place"
                        showVoteSheet = true
                    }
                }
                if let time = viewModel.pod?.scheduledTime {
                    ActionChip(icon: "calendar.badge.checkmark", label: "Add to Calendar") {
                        addToCalendar(time: time, place: viewModel.pod?.scheduledPlace)
                    }
                }

                // Only the pod leader can invite people or delete the pod.
                if isLeader {
                    ActionChip(icon: "person.badge.plus", label: "Invite") {
                        showInviteSheet = true
                    }
                }
                ActionChip(icon: "rectangle.portrait.and.arrow.right", label: "Leave Pod") {
                    showLeaveAlert = true
                }
                if isLeader {
                    ActionChip(icon: "trash", label: "Delete Pod") {
                        showDeleteAlert = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Waiting For Members Banner

    /// Pods need a minimum number of people (3+) before the activity is a go.
    /// Compact: "👤+ +2 to launch".
    @ViewBuilder
    private var waitingForMembersBanner: some View {
        if let pod = viewModel.pod, pod.membersNeededForMinimum > 0 {
            HStack(spacing: 6) {
                Text("needs +\(pod.membersNeededForMinimum)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Image(systemName: "person.fill.badge.plus")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                Text("needs +\(pod.membersNeededForMinimum)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Text("to launch")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.08))

            Divider()
        }
    }

    // MARK: - Pinned Message Banner

    /// Shows the most recently pinned message, like Discord's pin bar.
    @ViewBuilder
    private var pinnedMessageBanner: some View {
        if let pinnedMsg = viewModel.messages.last(where: { $0.pinned }) {
            HStack(spacing: 10) {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(OrbitTheme.gradient)

                VStack(alignment: .leading, spacing: 1) {
                    Text(memberName(pinnedMsg.userId))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(pinnedMsg.content)
                        .font(.caption)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))

            Divider()
        }
    }

    // MARK: - Confirmed Details Banner

    @ViewBuilder
    private var confirmedDetailsBanner: some View {
        let time = viewModel.pod?.displayTime
        let place = viewModel.pod?.scheduledPlace
        if time != nil || place != nil {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(OrbitTheme.gradient)

                VStack(alignment: .leading, spacing: 2) {
                    if let time = time {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(time)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    if let place = place, !place.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(place)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(OrbitTheme.gradient.opacity(0.08))

            Divider()
        }
    }

    // MARK: - Activity Completed Banner

    @ViewBuilder
    private var activityCompletedBanner: some View {
        if let pod = viewModel.pod, pod.isActivityCompleted {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(hex: "059669"))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity completed!")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if let expiresAt = pod.parsedExpiresAt {
                        let remaining = expiresAt.timeIntervalSince(Date())
                        if remaining > 0 {
                            let minutes = Int(remaining / 60)
                            let hours = minutes / 60
                            let mins = minutes % 60
                            Text("Pod will remain for \(hours > 0 ? "\(hours)h " : "")\(mins)m")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Pod is being removed...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Pod will remain for two more hours.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "059669").opacity(0.08))

            Divider()
        }
    }

    // MARK: - Chat Body

    private var chatBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    // Flex scheduling hint when no messages yet
                    if missionMode == .flex && viewModel.messages.isEmpty && !viewModel.isLoading {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 32))
                                .foregroundStyle(OrbitTheme.gradient)
                            Text("Scheduling in progress")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Add your availability above, then chat with your pod while you wait for others.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .padding(.horizontal, 24)
                    }

                    ForEach(viewModel.messages) { message in
                        if message.isSystemMessage {
                            SystemMessageBubble(message: message)
                                .id(message.id)
                        } else {
                            ChatBubble(
                                message: message,
                                isCurrentUser: message.userId == currentUserId,
                                senderName: viewModel.pod?.members?.first(where: { $0.userId == message.userId })?.name ?? "?",
                                currentUserId: currentUserId,
                                isLeader: isLeader,
                                nameFor: { uid in memberName(uid) },
                                onReact: { reaction in
                                    Task { await viewModel.reactToMessage(messageId: message.id, reaction: reaction) }
                                },
                                onTogglePin: {
                                    Task { await viewModel.togglePin(message: message) }
                                },
                                onDelete: {
                                    Task { await viewModel.deleteMessage(messageId: message.id) }
                                }
                            )
                            .id(message.id)
                        }
                    }

                    // Inline vote cards
                    ForEach(viewModel.votes) { vote in
                        VoteCardView(vote: vote, currentUserId: currentUserId) { voteId, optionIndex in
                            Task { await viewModel.castVote(voteId: voteId, optionIndex: optionIndex) }
                        } onRemoveVote: { voteId in
                            Task { await viewModel.removeVote(voteId: voteId) }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) {
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Say something...", text: $viewModel.messageText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button(action: {
                Task { await viewModel.sendMessage() }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        OrbitTheme.gradient
                    )
            }
            .disabled(viewModel.messageText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: - Add to Calendar

    private func addToCalendar(time: String, place: String?) {
        var components = URLComponents(string: "https://calendar.google.com/calendar/render")!
        var items = [
            URLQueryItem(name: "action", value: "TEMPLATE"),
            URLQueryItem(name: "text", value: displayTitle),
        ]
        if let place = place { items.append(URLQueryItem(name: "location", value: place)) }
        components.queryItems = items
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Member Strip

struct MemberStripView: View {
    let members: [PodMember]
    let currentUserId: Int
    let onKick: (PodMember) -> Void
    var onTapMember: ((PodMember) -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(members) { member in
                    Button {
                        onTapMember?(member)
                    } label: {
                        VStack(spacing: 4) {
                            ProfileAvatarView(
                                photo: member.photo,
                                size: 44,
                                name: member.name
                            )

                            Text(member.name)
                                .font(.caption2)
                                .lineLimit(1)
                            Text(Profile.displayYear(member.collegeYear))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if member.userId != currentUserId {
                            Button(role: .destructive) {
                                onKick(member)
                            } label: {
                                Label("Kick \(member.name)", systemImage: "person.fill.xmark")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [OrbitTheme.pink, OrbitTheme.purple, OrbitTheme.blue]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Chat Bubble
// Discord-style: hold a message to react (👍 👎 ❤️), pin (leader only), or
// delete (own messages only). Reaction counts show under the bubble; hold the
// reactions to see who reacted with what.

struct ChatBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    let senderName: String
    var currentUserId: Int = 0
    var isLeader: Bool = false
    var nameFor: (Int) -> String = { _ in "Someone" }
    var onReact: ((String) -> Void)? = nil
    var onTogglePin: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var showReactors = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isCurrentUser {
                    Text(senderName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
                bubbleContent
                    .contextMenu { messageActions }

                if !message.activeReactions.isEmpty {
                    reactionChips
                }
            }

            if !isCurrentUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .alert("Reactions", isPresented: $showReactors) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reactorSummary)
        }
    }

    private var bubbleContent: some View {
        HStack(spacing: 4) {
            if message.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundColor(isCurrentUser ? .white.opacity(0.85) : .secondary)
            }
            Text(message.content)
                .font(.body)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            isCurrentUser
            ? AnyShapeStyle(OrbitTheme.gradient)
            : AnyShapeStyle(Color(.systemGray5))
        )
        .foregroundColor(isCurrentUser ? .white : .primary)
        .clipShape(
            RoundedRectangle(cornerRadius: 18)
        )
    }

    // Long-press menu: emoji reactions row + pin (leader) + delete (own).
    @ViewBuilder
    private var messageActions: some View {
        ControlGroup {
            ForEach(ChatMessage.reactionOptions, id: \.key) { option in
                Button(option.emoji) { onReact?(option.key) }
            }
        }
        .controlGroupStyle(.compactMenu)

        if isLeader {
            Button {
                onTogglePin?()
            } label: {
                Label(message.pinned ? "Unpin" : "Pin", systemImage: "pin")
            }
        }

        if isCurrentUser {
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    /// Reaction chips under the bubble — tap to toggle, hold to see who reacted.
    private var reactionChips: some View {
        HStack(spacing: 6) {
            ForEach(message.activeReactions, id: \.key) { reaction in
                let mine = reaction.userIds.contains(currentUserId)
                HStack(spacing: 4) {
                    Text(reaction.emoji)
                        .font(.caption)
                    Text("\(reaction.userIds.count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    mine
                    ? AnyShapeStyle(OrbitTheme.gradient.opacity(0.18))
                    : AnyShapeStyle(Color(.systemGray6))
                )
                .overlay(
                    Capsule().stroke(
                        mine ? AnyShapeStyle(OrbitTheme.gradient) : AnyShapeStyle(Color.clear),
                        lineWidth: 1
                    )
                )
                .clipShape(Capsule())
                .onTapGesture { onReact?(reaction.key) }
                .onLongPressGesture { showReactors = true }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    /// e.g. "👍 You, Alex\n❤️ Sam" — shown when holding the reaction chips.
    private var reactorSummary: String {
        message.activeReactions.map { reaction in
            "\(reaction.emoji) " + reaction.userIds.map { nameFor($0) }.joined(separator: ", ")
        }.joined(separator: "\n")
    }
}

// MARK: - System Message Bubble

struct SystemMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            Spacer()
            Text(message.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }
}

// MARK: - Action Chip

struct ActionChip: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(
                        OrbitTheme.gradient
                    )
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Pod Sheet (leader only)
// Edits the whole pod, not just the name — e.g. the group agrees a different
// spot works better, the leader updates it, and everyone sees the change
// (a system message announces it in the chat).

struct EditPodSheet: View {
    let initialName: String
    let initialPlace: String
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var place: String
    @State private var showLocationSearch = false

    init(initialName: String, initialPlace: String, onSave: @escaping (String, String) -> Void) {
        self.initialName = initialName
        self.initialPlace = initialPlace
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _place = State(initialValue: initialPlace)
    }

    private var hasChanges: Bool {
        name.trimmingCharacters(in: .whitespaces) != initialName
            || place.trimmingCharacters(in: .whitespaces) != initialPlace
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pod name") {
                    TextField("Pod name", text: $name)
                }

                Section {
                    Button {
                        showLocationSearch = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(OrbitTheme.gradient)
                            Text(place.isEmpty ? "Add a meeting place" : place)
                                .foregroundColor(place.isEmpty ? .secondary : .primary)
                                .lineLimit(2)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if !place.isEmpty {
                        Button("Clear meeting place", role: .destructive) {
                            place = ""
                        }
                    }
                } header: {
                    Text("Meeting place")
                } footer: {
                    Text("Changes are announced in the pod chat so everyone sees them.")
                }
            }
            .navigationTitle("Edit Pod")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            name.trimmingCharacters(in: .whitespaces),
                            place.trimmingCharacters(in: .whitespaces)
                        )
                        dismiss()
                    }
                    .disabled(!hasChanges)
                }
            }
            .sheet(isPresented: $showLocationSearch) {
                LocationSearchView(locationName: $place)
            }
        }
    }
}

// MARK: - Create Vote Sheet

struct CreateVoteSheet: View {
    let voteType: String
    let onCreate: ([String]) -> Void
    let onCancel: () -> Void

    private var isTimeVote: Bool { voteType == "time" }

    // Text options (for place votes)
    @State private var options: [String] = ["", ""]

    // Date options (for time votes)
    @State private var dateOptions: [Date] = {
        let now = Date()
        return [now, now.addingTimeInterval(3600)]
    }()

    private var isValid: Bool {
        if isTimeVote {
            return dateOptions.count >= 2
        }
        return options.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 2
    }

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d · h:mm a"
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                if isTimeVote {
                    Section("Pick date & time options (2–4)") {
                        ForEach(0..<dateOptions.count, id: \.self) { i in
                            DatePicker(
                                "Option \(i + 1)",
                                selection: $dateOptions[i],
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                        if dateOptions.count < 4 {
                            Button("Add option") {
                                dateOptions.append(Date().addingTimeInterval(Double(dateOptions.count) * 3600))
                            }
                        }
                    }
                } else {
                    Section("Options (2–4)") {
                        ForEach(0..<options.count, id: \.self) { i in
                            TextField("Option \(i + 1)", text: $options[i])
                        }
                        if options.count < 4 {
                            Button("Add option") { options.append("") }
                        }
                    }
                }
            }
            .navigationTitle("Vote on \(voteType)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if isTimeVote {
                            let formatted = dateOptions.map { Self.displayFormatter.string(from: $0) }
                            onCreate(formatted)
                        } else {
                            let cleaned = options.map { $0.trimmingCharacters(in: .whitespaces) }
                                                .filter { !$0.isEmpty }
                            onCreate(cleaned)
                        }
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
