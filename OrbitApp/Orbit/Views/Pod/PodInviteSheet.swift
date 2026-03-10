import SwiftUI

struct PodInviteSheet: View {
    let podId: String
    let currentMemberIds: [Int]
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [Friendship] = []
    @State private var isLoading = true
    @State private var sentInviteIds: Set<Int> = []
    @State private var sendingIds: Set<Int> = []
    @State private var errorMessage: String?

    /// Friends who are not already pod members
    private var invitableFriends: [Friendship] {
        friends.filter { f in
            guard let friendId = f.friend?.userId else { return false }
            return !currentMemberIds.contains(friendId)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(OrbitTheme.purple)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if invitableFriends.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("no friends to invite")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("all your friends are already in this pod, or you haven't added any friends yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(invitableFriends) { friendship in
                                inviteRow(friendship: friendship)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task { await loadFriends() }
    }

    @ViewBuilder
    private func inviteRow(friendship: Friendship) -> some View {
        let friend = friendship.friend
        let friendId = friend?.userId ?? 0
        let alreadySent = sentInviteIds.contains(friendId)
        let isSending = sendingIds.contains(friendId)

        HStack(spacing: 12) {
            ProfileAvatarView(
                photo: friend?.photo,
                size: 44,
                name: friend?.name
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(friend?.name ?? "Friend")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if let year = friend?.collegeYear, !year.isEmpty {
                    Text(Profile.displayYear(year))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if alreadySent {
                Text("sent")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
            } else {
                Button {
                    Task { await sendInvite(toUserId: friendId) }
                } label: {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 60, height: 28)
                    } else {
                        Text("Invite")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                    }
                }
                .background(OrbitTheme.gradientFill)
                .clipShape(Capsule())
                .disabled(isSending)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func loadFriends() async {
        isLoading = true
        do {
            friends = try await FriendService.shared.getFriends()
        } catch {
            print("[PodInvite] load friends error: \(error)")
        }
        isLoading = false
    }

    private func sendInvite(toUserId: Int) async {
        sendingIds.insert(toUserId)
        do {
            _ = try await PodService.shared.sendInvite(podId: podId, toUserId: toUserId)
            sentInviteIds.insert(toUserId)
        } catch {
            errorMessage = error.localizedDescription
        }
        sendingIds.remove(toUserId)
    }
}
