import Foundation
import Combine

@MainActor
class PodViewModel: ObservableObject {
    @Published var pod: Pod?
    @Published var messages: [ChatMessage] = []
    @Published var votes: [Vote] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var isLeaving = false
    @Published var didLeave = false
    @Published var errorMessage: String?
    @Published var messageText: String = ""
    @Published var podNotFound = false
    @Published var notAMember = false

    // Flex mode routing
    @Published var missionMode: MissionMode = .set
    @Published var mission: Mission?

    private let podId: String

    init(podId: String, missionMode: MissionMode = .set) {
        self.podId = podId
        self.missionMode = missionMode
    }

    /// Whether this pod is in flex scheduling (pre-chat) state.
    var isFlexForming: Bool {
        missionMode == .flex && pod?.status != "meeting_confirmed" && pod?.status != "cancelled"
    }

    func load(retryCount: Int = 0) async {
        isLoading = true

        // Each request is independent — one failure must not block the others.
        do { pod = try await PodService.shared.getPod(id: podId) }
        catch {
            let msg = error.localizedDescription.lowercased()
            // Pod may not be ready yet right after joining — retry once.
            if retryCount < 2 {
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
                await load(retryCount: retryCount + 1)
                return
            }
            // Pod doesn't exist on backend — signal auto-dismiss
            if msg.contains("not found") || msg.contains("expired") {
                podNotFound = true
                isLoading = false
                return
            }
            // User isn't in this pod's member list — let them remove it
            if msg.contains("not a member") {
                notAMember = true
                isLoading = false
                return
            }
            errorMessage = error.localizedDescription
        }

        // Populate local schedule grid from backend data.
        if let pod = pod {
            ScheduleService.shared.populateFromBackend(podId: podId, data: pod.scheduleData)
        }

        // Resolve mission mode from the pod's missionId if not already known.
        if let pod = pod {
            do {
                let m = try await MissionService.shared.getMission(id: pod.missionId)
                mission = m
                missionMode = m.mode
            } catch {
                // Keep whatever mode was passed in init
            }
        }

        do { messages = try await ChatService.shared.getMessages(podId: podId) }
        catch { /* empty messages is fine for a new pod */ }

        do { votes = try await ChatService.shared.getVotes(podId: podId) }
        catch { /* empty votes is fine for a new pod */ }

        // Mark this pod's chat as read
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "pod_last_seen_\(podId)")

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

    func removeVote(voteId: String) async {
        do {
            let updated = try await ChatService.shared.removeVote(
                podId: podId, voteId: voteId
            )
            if let idx = votes.firstIndex(where: { $0.id == voteId }) {
                votes[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leavePod() async {
        isLeaving = true
        do {
            try await PodService.shared.leavePod(podId: podId)
            didLeave = true
        } catch {
            // If the server says we're not a member, treat as successful leave
            // so the user can remove this stale pod from their list.
            let msg = error.localizedDescription.lowercased()
            if msg.contains("not a member") || msg.contains("not found") {
                didLeave = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLeaving = false
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
