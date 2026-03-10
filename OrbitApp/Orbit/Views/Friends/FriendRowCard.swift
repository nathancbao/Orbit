import SwiftUI

struct FriendRowCard: View {
    let friendship: Friendship
    @State private var showProfile = false
    @State private var showDMChat = false

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
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(OrbitTheme.gradient)
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
