import Foundation
import Combine

@MainActor
class DMChatViewModel: ObservableObject {
    let friendId: Int
    let friendName: String

    @Published var messages: [ChatMessage] = []
    @Published var messageText: String = ""
    @Published var isSending = false
    @Published var errorMessage: String?

    private var pollTimer: Timer?
    private let currentUserId: Int = UserDefaults.standard.integer(forKey: "orbit_user_id")

    init(friendId: Int, friendName: String) {
        self.friendId = friendId
        self.friendName = friendName
    }

    func load() async {
        do {
            messages = try await ChatService.shared.getDMMessages(friendId: friendId)
            // Mark conversation as read
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "dm_last_seen_\(friendId)")
        } catch {
            print("[DM] load error: \(error)")
        }
    }

    func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSending = true
        messageText = ""
        do {
            let msg = try await ChatService.shared.sendDMMessage(friendId: friendId, content: text)
            messages.append(msg)
        } catch {
            errorMessage = error.localizedDescription
            messageText = text
        }
        isSending = false
    }

    func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.load()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
