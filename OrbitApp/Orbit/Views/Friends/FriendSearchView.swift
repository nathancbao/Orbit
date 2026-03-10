import SwiftUI

// MARK: - Friend Search View
// Search for users by email to send friend requests.

struct FriendSearchView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search by email or name", text: $viewModel.userSearchText)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isSearchFocused)
                    if !viewModel.userSearchText.isEmpty {
                        Button {
                            viewModel.userSearchText = ""
                            viewModel.userSearchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if viewModel.isSearching {
                    ProgressView()
                        .tint(OrbitTheme.purple)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.userSearchText.trimmingCharacters(in: .whitespaces).count < 3 {
                    // Hint state
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "person.crop.circle.badge.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Type an email or name to find people")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else if viewModel.userSearchResults.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "person.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No users found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.userSearchResults) { user in
                                SearchResultCard(
                                    user: user,
                                    alreadySent: viewModel.sentRequestUserIds.contains(user.userId),
                                    onSendRequest: {
                                        Task { await viewModel.sendRequestFromSearch(toUserId: user.userId) }
                                    }
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Find Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { isSearchFocused = true }
        .onChange(of: viewModel.userSearchText) { _, _ in
            viewModel.searchUsers()
        }
        .onDisappear {
            viewModel.userSearchText = ""
            viewModel.userSearchResults = []
        }
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let user: FriendProfile
    let alreadySent: Bool
    let onSendRequest: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor(for: user.name))
                    .frame(width: 44, height: 44)
                if let photo = user.photo, let url = URL(string: photo) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Text(String(user.name.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Text(String(user.name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if !user.collegeYear.isEmpty {
                    Text(Profile.displayYear(user.collegeYear))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Add button
            if alreadySent {
                Label("Sent", systemImage: "clock")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            } else {
                Button(action: onSendRequest) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(8)
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

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [OrbitTheme.pink, OrbitTheme.purple, OrbitTheme.blue]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}
