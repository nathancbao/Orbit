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

    /// Full initial load of the conversation history.
    func load() async {
        do {
            messages = try await ChatService.shared.getDMMessages(friendId: friendId)
            markRead()
        } catch {
            print("[DM] load error: \(error)")
        }
    }

    /// Incremental refresh: fetch only messages newer than the latest we hold,
    /// then append. Keeps each poll at ~1 Datastore read when nothing is new.
    private func poll() async {
        let since = messages.last?.createdAt
        do {
            let incoming = try await ChatService.shared.getDMMessages(friendId: friendId, since: since)
            guard !incoming.isEmpty else { return }
            let existing = Set(messages.map(\.id))
            let fresh = incoming.filter { !existing.contains($0.id) }
            guard !fresh.isEmpty else { return }
            messages.append(contentsOf: fresh)
            markRead()
        } catch {
            print("[DM] poll error: \(error)")
        }
    }

    private func markRead() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "dm_last_seen_\(friendId)")
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
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.poll()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
