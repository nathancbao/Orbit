import SwiftUI

// MARK: - Friends View (Tab Root)

struct FriendsView: View {
    @Binding var userProfile: Profile
    var isActive: Bool = false

    @StateObject private var viewModel = FriendsViewModel()
    @State private var showProfile = false
    @State private var showInbox = false
    @State private var showSearch = false
    @State private var friendToRemove: Friendship?

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
                        Text("search by email or name to add friends")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button { showSearch = true } label: {
                            Label("Find Friends", systemImage: "magnifyingglass")
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

                        List {
                            ForEach(viewModel.filteredFriends) { friendship in
                                FriendRowCard(
                                    friendship: friendship,
                                    hasUnread: viewModel.unreadFriendIds.contains(friendship.friend?.userId ?? -1)
                                )
                                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        friendToRemove = friendship
                                    } label: {
                                        Label("Remove", systemImage: "person.badge.minus")
                                    }
                                }
                            }

                            if viewModel.filteredFriends.isEmpty && !viewModel.searchText.isEmpty {
                                Text("no matches")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .refreshable { await viewModel.loadAll() }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                            Task { await viewModel.loadAll() }
                        }
                        .confirmationDialog(
                            "Remove \(friendToRemove?.friend?.name ?? "Friend")?",
                            isPresented: Binding(get: { friendToRemove != nil }, set: { if !$0 { friendToRemove = nil } }),
                            titleVisibility: .visible
                        ) {
                            Button("Remove Friend", role: .destructive) {
                                if let f = friendToRemove { Task { await viewModel.removeFriend(f) } }
                                friendToRemove = nil
                            }
                            Button("Cancel", role: .cancel) { friendToRemove = nil }
                        } message: {
                            Text("They won't be notified.")
                        }
                    }
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 16) {
                        Button { showInbox = true } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "tray")
                                    .font(.system(size: 18))
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
                        Button { showSearch = true } label: {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 18))
                                .fontWeight(.medium)
                                .foregroundStyle(Color.primary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showProfile = true } label: {
                        ProfileAvatarView(photo: userProfile.photo, size: 34, name: userProfile.name)
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
        .sheet(isPresented: $showSearch) {
            FriendSearchView(viewModel: viewModel)
        }
        .task { await viewModel.loadAll() }
        .onChange(of: isActive) { _, active in
            if active { Task { await viewModel.loadAll() } }
        }
    }
}
