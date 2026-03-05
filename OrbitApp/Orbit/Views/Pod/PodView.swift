import SwiftUI

// MARK: - Pod View
// Chat screen for a pod. Shows member strip + messages + vote cards + action bar.

struct PodView: View {
    let podId: String
    let title: String
    let missionMode: MissionMode

    @StateObject private var viewModel: PodViewModel
    @State private var scheduleVM: ScheduleViewModel?
    @State private var showVoteSheet = false
    @State private var voteSheetType: String = "time"
    @State private var showScheduleSheet = false
    @State private var showKickSheet = false
    @State private var kickTarget: PodMember?
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showLeaveAlert = false
    @State private var selectedMemberProfile: Profile?
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

    init(podId: String, title: String, missionMode: MissionMode = .set) {
        self.podId = podId
        self.title = title
        self.missionMode = missionMode
        _viewModel = StateObject(wrappedValue: PodViewModel(podId: podId, missionMode: missionMode))
    }

    var body: some View {
        podViewWithSheets
            .onChange(of: viewModel.didLeave) {
                if viewModel.didLeave { dismiss() }
            }
            .onChange(of: viewModel.isLoading) {
                if !viewModel.isLoading { createScheduleVMIfNeeded() }
            }
            .task {
                await viewModel.load()
                createScheduleVMIfNeeded()
                if missionMode == .flex,
                   let pod = viewModel.pod,
                   pod.scheduleData?.entries[String(currentUserId)] == nil {
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
            .sheet(item: $selectedMemberProfile) { profile in
                ProfileDisplayView(profile: profile)
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
        .alert("Rename Pod", isPresented: $showRenameAlert) {
            TextField("Pod name", text: $renameText)
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                Task { await viewModel.renamePod(name: trimmed) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Give your pod a name")
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
    }

    // MARK: - Main Content (broken out for type-checker)

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            existingChatContent
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Close") { dismiss() }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                renameText = viewModel.pod?.name ?? ""
                showRenameAlert = true
            } label: {
                Image(systemName: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(OrbitTheme.gradient)
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

            // Action bar
            actionBar

            Divider()

            // Chat messages
            chatBody

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
                    selectedMemberProfile = profile
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
                if missionMode == .flex {
                    ActionChip(icon: "calendar.badge.plus", label: "Availability") {
                        showScheduleSheet = true
                    }
                }
                ActionChip(icon: "clock", label: "Vote time") {
                    voteSheetType = "time"
                    showVoteSheet = true
                }
                ActionChip(icon: "mappin", label: "Vote place") {
                    voteSheetType = "place"
                    showVoteSheet = true
                }
                if let time = viewModel.pod?.scheduledTime {
                    ActionChip(icon: "calendar.badge.checkmark", label: "Add to Calendar") {
                        addToCalendar(time: time, place: viewModel.pod?.scheduledPlace)
                    }
                }
                if shouldShowConfirmButton {
                    ActionChip(icon: "checkmark.seal", label: "I showed up!") {
                        Task { await viewModel.confirmAttendance() }
                    }
                }
                ActionChip(icon: "rectangle.portrait.and.arrow.right", label: "Leave Pod") {
                    showLeaveAlert = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    private var shouldShowConfirmButton: Bool {
        guard let pod = viewModel.pod else { return false }
        let hasTime = pod.scheduledTime != nil
        let notConfirmed = !(pod.confirmedAttendees.contains(currentUserId))
        return hasTime && notConfirmed
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
                                senderName: viewModel.pod?.members?.first(where: { $0.userId == message.userId })?.name ?? "?"
                            )
                            .id(message.id)
                        }
                    }

                    // Inline vote cards
                    ForEach(viewModel.votes) { vote in
                        VoteCardView(vote: vote, currentUserId: currentUserId) { voteId, optionIndex in
                            Task { await viewModel.castVote(voteId: voteId, optionIndex: optionIndex) }
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
                            ZStack {
                                Circle()
                                    .fill(avatarColor(for: member.name))
                                    .frame(width: 44, height: 44)
                                Text(String(member.name.prefix(1)).uppercased())
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }

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

struct ChatBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    let senderName: String

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
                Text(message.content)
                    .font(.body)
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

            if !isCurrentUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
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

// MARK: - Create Vote Sheet

struct CreateVoteSheet: View {
    let voteType: String
    let onCreate: ([String]) -> Void
    let onCancel: () -> Void

    @State private var options: [String] = ["", ""]
    @State private var newOption: String = ""

    private var isValid: Bool {
        options.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 2
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Options (2–4)") {
                    ForEach(0..<options.count, id: \.self) { i in
                        TextField("Option \(i + 1)", text: $options[i])
                    }
                    if options.count < 4 {
                        Button("Add option") { options.append("") }
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
                        let cleaned = options.map { $0.trimmingCharacters(in: .whitespaces) }
                                            .filter { !$0.isEmpty }
                        onCreate(cleaned)
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
