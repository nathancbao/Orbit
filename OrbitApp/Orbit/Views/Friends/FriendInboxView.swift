import SwiftUI

struct FriendInboxView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Incoming Requests
                    if !viewModel.incomingRequests.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Incoming Requests")
                                .font(.headline)
                                .padding(.horizontal, 20)

                            ForEach(viewModel.incomingRequests) { request in
                                IncomingRequestCard(
                                    request: request,
                                    onAccept: { Task { await viewModel.acceptRequest(request) } },
                                    onDecline: { Task { await viewModel.declineRequest(request) } }
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                    }

                    // Outgoing Requests
                    if !viewModel.outgoingRequests.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sent Requests")
                                .font(.headline)
                                .padding(.horizontal, 20)

                            ForEach(viewModel.outgoingRequests) { request in
                                OutgoingRequestCard(request: request)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }

                    // Empty state
                    if viewModel.incomingRequests.isEmpty && viewModel.outgoingRequests.isEmpty {
                        VStack(spacing: 12) {
                            Spacer(minLength: 80)
                            Image(systemName: "tray")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("no pending requests")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
    }
}

// MARK: - Incoming Request Card

struct IncomingRequestCard: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(
                photo: request.fromUser?.photo,
                size: 44,
                name: request.fromUser?.name
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromUser?.name ?? "Someone")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if let year = request.fromUser?.collegeYear, !year.isEmpty {
                    Text(Profile.displayYear(year))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onDecline) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }

                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(OrbitTheme.gradientFill)
                        .clipShape(Circle())
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Outgoing Request Card

struct OutgoingRequestCard: View {
    let request: FriendRequest

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(
                photo: request.toUser?.photo,
                size: 44,
                name: request.toUser?.name
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(request.toUser?.name ?? "User")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if let year = request.toUser?.collegeYear, !year.isEmpty {
                    Text(Profile.displayYear(year))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text("pending")
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.15))
                .foregroundColor(.orange)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
