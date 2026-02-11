//
//  OutgoingRequestRowView.swift
//  Orbit
//
//  Row component for displaying an outgoing (sent) friend request with cancel option.
//

import SwiftUI

struct OutgoingRequestRowView: View {
    let request: FriendRequest
    let onCancel: () -> Void

    @State private var isProcessing = false

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(
                photoURL: request.toUserProfile.photos.first,
                size: 50
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(request.toUserProfile.name)
                    .font(.headline)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Pending")
                        .font(.caption)
                }
                .foregroundColor(.orange)

                Text(timeAgoString(from: request.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                isProcessing = true
                onCancel()
            }) {
                Text("Cancel")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            .disabled(isProcessing)
        }
        .padding(.vertical, 8)
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
