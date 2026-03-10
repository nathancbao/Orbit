import SwiftUI

struct DMChatView: View {
    let friendId: Int
    let friendName: String
    let friendPhoto: String?

    @StateObject private var viewModel: DMChatViewModel
    @Environment(\.dismiss) private var dismiss

    private let currentUserId: Int = UserDefaults.standard.integer(forKey: "orbit_user_id")

    init(friendId: Int, friendName: String, friendPhoto: String? = nil) {
        self.friendId = friendId
        self.friendName = friendName
        self.friendPhoto = friendPhoto
        _viewModel = StateObject(wrappedValue: DMChatViewModel(friendId: friendId, friendName: friendName))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chatBody
                inputBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(friendName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.load()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    // MARK: - Chat Body

    private var chatBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if viewModel.messages.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 32))
                                .foregroundStyle(OrbitTheme.gradient)
                            Text("Start a conversation")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Send a message to \(friendName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }

                    ForEach(viewModel.messages) { message in
                        ChatBubble(
                            message: message,
                            isCurrentUser: message.userId == currentUserId,
                            senderName: message.userId == currentUserId ? "You" : friendName
                        )
                        .id(message.id)
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
                    .foregroundStyle(OrbitTheme.gradient)
            }
            .disabled(viewModel.messageText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}
