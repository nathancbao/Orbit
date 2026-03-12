import SwiftUI

struct FriendRowCard: View {
    let friendship: Friendship
    var hasUnread: Bool = false
    var onRemove: (() -> Void)?
    @State private var showProfile = false
    @State private var showDMChat = false
    @State private var showRemoveConfirm = false

    var body: some View {
        Button(action: { showProfile = true }) {
            HStack(spacing: 14) {
                ProfileAvatarView(
                    photo: friendship.friend?.photo,
                    size: 48,
                    name: friendship.friend?.name
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(friendship.friend?.name ?? "Friend")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let year = friendship.friend?.collegeYear, !year.isEmpty {
                        Text(Profile.displayYear(year))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // DM button
                Button {
                    showDMChat = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(OrbitTheme.gradient)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                        if hasUnread {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Remove friend button
                Button {
                    showRemoveConfirm = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            "Are you sure you want to remove \(friendship.friend?.name ?? "this friend")?",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove Friend", role: .destructive) {
                onRemove?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be notified.")
        }
        .sheet(isPresented: $showProfile) {
            if let friend = friendship.friend {
                ProfileDisplayView(
                    profile: Profile(
                        name: friend.name,
                        collegeYear: friend.collegeYear,
                        interests: friend.interests,
                        photo: friend.photo,
                        bio: friend.bio
                    ),
                    otherUserId: friend.userId
                )
            }
        }
        .sheet(isPresented: $showDMChat) {
            if let friend = friendship.friend {
                DMChatView(
                    friendId: friend.userId,
                    friendName: friend.name,
                    friendPhoto: friend.photo
                )
            }
        }
    }
}
