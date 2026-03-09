import SwiftUI

// MARK: - Friends View (Tab Root)

struct FriendsView: View {
    @Binding var userProfile: Profile
    var isActive: Bool = false

    @StateObject private var viewModel = FriendsViewModel()
    @State private var showProfile = false
    @State private var showInbox = false
    @State private var showShareSheet = false

    private var currentUserId: Int {
        UserDefaults.standard.integer(forKey: "orbit_user_id")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if viewModel.isLoading && viewModel.friends.isEmpty {
                    ProgressView()
                        .tint(OrbitTheme.purple)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.friends.isEmpty && viewModel.incomingRequests.isEmpty && viewModel.outgoingRequests.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48))
                            .foregroundStyle(OrbitTheme.gradient)
                        Text("no friends yet")
                            .font(.headline)
                        Text("share your link or QR code to add friends")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button { showShareSheet = true } label: {
                            Label("Share My Link", systemImage: "square.and.arrow.up")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(OrbitTheme.gradientFill)
                                .clipShape(Capsule())
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search friends", text: $viewModel.searchText)
                        }
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.filteredFriends) { friendship in
                                    FriendRowCard(friendship: friendship)
                                        .padding(.horizontal, 20)
                                }

                                if viewModel.filteredFriends.isEmpty && !viewModel.searchText.isEmpty {
                                    Text("no matches")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 40)
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 80)
                        }
                        .refreshable { await viewModel.loadAll() }
                    }
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showInbox = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "tray")
                                .fontWeight(.medium)
                                .foregroundStyle(Color.primary)
                            if viewModel.inboxCount > 0 {
                                Text("\(viewModel.inboxCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(3)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button { showShareSheet = true } label: {
                            Image(systemName: "qrcode")
                                .fontWeight(.medium)
                                .foregroundStyle(Color.primary)
                        }
                        Button { showProfile = true } label: {
                            ProfileAvatarView(photo: userProfile.photo, size: 30, name: userProfile.name)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileDisplayView(
                profile: userProfile,
                onEdit: { showProfile = false },
                onProfileUpdated: { updated in userProfile = updated }
            )
        }
        .sheet(isPresented: $showInbox) {
            FriendInboxView(viewModel: viewModel)
        }
        .sheet(isPresented: $showShareSheet) {
            FriendShareView(userId: currentUserId, userName: userProfile.name)
        }
        .task { await viewModel.loadAll() }
        .onChange(of: isActive) { _, active in
            if active { Task { await viewModel.loadAll() } }
        }
    }
}
