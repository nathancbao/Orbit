//
//  FriendRowView.swift
//  Orbit
//
//  Row component for displaying a friend in a list.
//

import SwiftUI

struct FriendRowView: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(
                photoURL: friend.friendProfile.photos.first,
                size: 50
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.friendProfile.name)
                    .font(.headline)

                Text("\(friend.friendProfile.location.city), \(friend.friendProfile.location.state)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
