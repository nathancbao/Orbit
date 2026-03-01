import Foundation
import Combine

@MainActor
class PodViewModel: ObservableObject {
    @Published var pod: EventPod?
    @Published var messages: [ChatMessage] = []
    @Published var votes: [Vote] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var messageText: String = ""

    private let podId: String
    private var currentUserId: Int = 0  // Set from Keychain on init

    init(podId: String) {
        self.podId = podId
    }

    func load() async {
        isLoading = true
        do {
            async let podResult = PodService.shared.getPod(id: podId)
            async let msgsResult = ChatService.shared.getMessages(podId: podId)
            async let votesResult = ChatService.shared.getVotes(podId: podId)
            pod = try await podResult
            messages = try await msgsResult
            votes = try await votesResult
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func sendMessage() async {
        let content = messageText.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        isSending = true
        messageText = ""
        do {
            let msg = try await ChatService.shared.sendMessage(podId: podId, content: content)
            messages.append(msg)
        } catch {
            errorMessage = error.localizedDescription
            messageText = content  // restore on error
        }
        isSending = false
    }

    func createVote(type: String, options: [String]) async {
        do {
            let vote = try await ChatService.shared.createVote(podId: podId, voteType: type, options: options)
            votes.append(vote)
            // Refresh messages to show the system message
            messages = (try? await ChatService.shared.getMessages(podId: podId)) ?? messages
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func castVote(voteId: String, optionIndex: Int) async {
        do {
            let updated = try await ChatService.shared.respondToVote(
                podId: podId, voteId: voteId, optionIndex: optionIndex
            )
            if let idx = votes.firstIndex(where: { $0.id == voteId }) {
                votes[idx] = updated
            }
            // Refresh messages if vote just closed (system message appears)
            if updated.status == "closed" {
                messages = (try? await ChatService.shared.getMessages(podId: podId)) ?? messages
                pod = try? await PodService.shared.getPod(id: podId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renamePod(name: String) async {
        do {
            pod = try await PodService.shared.renamePod(podId: podId, name: name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmAttendance() async {
        do {
            let response = try await PodService.shared.confirmAttendance(podId: podId)
            pod = response.pod
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func kickMember(userId: Int) async {
        do {
            let response = try await PodService.shared.kickMember(podId: podId, targetUserId: userId)
            pod = response.pod
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openVote(type: String) -> Vote? {
        votes.first { $0.voteType == type && $0.status == "open" }
    }
}
