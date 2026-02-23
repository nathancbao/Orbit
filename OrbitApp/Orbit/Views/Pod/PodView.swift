import SwiftUI

// MARK: - Pod View
// Chat screen for a pod. Shows member strip + messages + vote cards + action bar.

struct PodView: View {
    let podId: String
    let eventTitle: String

    @StateObject private var viewModel: PodViewModel
    @State private var showVoteSheet = false
    @State private var voteSheetType: String = "time"
    @State private var showKickSheet = false
    @State private var kickTarget: PodMember?
    @Environment(\.dismiss) private var dismiss

    // Retrieve current user id from keychain (simple approach)
    private let currentUserId: Int = {
        // AuthService stores userId in UserDefaults during login
        UserDefaults.standard.integer(forKey: "orbit_user_id")
    }()

    init(podId: String, eventTitle: String) {
        self.podId = podId
        self.eventTitle = eventTitle
        _viewModel = StateObject(wrappedValue: PodViewModel(podId: podId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Member strip
                    if let pod = viewModel.pod, let members = pod.members {
                        MemberStripView(
                            members: members,
                            currentUserId: currentUserId,
                            onKick: { member in
                                kickTarget = member
                                showKickSheet = true
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
            .navigationTitle(eventTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
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
            .task { await viewModel.load() }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
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
            .onChange(of: viewModel.messages.count) { _ in
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
            TextField("say something...", text: $viewModel.messageText, axis: .vertical)
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
                        LinearGradient(
                            colors: [Color(red: 0.9, green: 0.6, blue: 0.7), Color(red: 0.45, green: 0.55, blue: 0.85)],
                            startPoint: .leading, endPoint: .trailing
                        )
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
            URLQueryItem(name: "text", value: eventTitle),
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

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(members) { member in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(avatarColor(for: member.name))
                                .frame(width: 44, height: 44)
                            Text(String(member.name.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .contextMenu {
                            if member.userId != currentUserId {
                                Button(role: .destructive) {
                                    onKick(member)
                                } label: {
                                    Label("Kick \(member.name)", systemImage: "person.fill.xmark")
                                }
                            }
                        }

                        Text(member.name)
                            .font(.caption2)
                            .lineLimit(1)
                        Text(Profile.displayYear(member.collegeYear))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [
            Color(red: 0.9, green: 0.6, blue: 0.7),
            Color(red: 0.7, green: 0.65, blue: 0.85),
            Color(red: 0.45, green: 0.55, blue: 0.85),
            Color(red: 0.8, green: 0.6, blue: 0.8),
        ]
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
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color(red: 0.9, green: 0.6, blue: 0.7), Color(red: 0.45, green: 0.55, blue: 0.85)],
                            startPoint: .leading, endPoint: .trailing
                        ))
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
                        LinearGradient(
                            colors: [Color(red: 0.9, green: 0.6, blue: 0.7), Color(red: 0.45, green: 0.55, blue: 0.85)],
                            startPoint: .leading, endPoint: .trailing
                        )
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
