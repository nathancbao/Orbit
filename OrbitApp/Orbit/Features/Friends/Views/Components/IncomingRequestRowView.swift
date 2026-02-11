//
//  IncomingRequestRowView.swift
//  Orbit
//
//  Row component for displaying an incoming friend request with accept/deny buttons.
//

import SwiftUI

struct IncomingRequestRowView: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDeny: () -> Void

    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ProfileAvatarView(
                    photoURL: request.fromUserProfile.photos.first,
                    size: 50
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.fromUserProfile.name)
                        .font(.headline)

                    Text("\(request.fromUserProfile.location.city), \(request.fromUserProfile.location.state)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(timeAgoString(from: request.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: {
                    isProcessing = true
                    onDeny()
                }) {
                    Text("Decline")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                }
                .disabled(isProcessing)

                Button(action: {
                    isProcessing = true
                    onAccept()
                }) {
                    Text("Accept")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isProcessing)
            }
        }
        .padding(.vertical, 8)
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
