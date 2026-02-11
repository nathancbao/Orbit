//
//  FriendsListView.swift
//  Orbit
//
//  Displays the list of all friends.
//

import SwiftUI

struct FriendsListView: View {
    @EnvironmentObject private var viewModel: FriendsViewModel
    @State private var selectedFriend: Friend?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingFriends && viewModel.friends.isEmpty {
                    ProgressView("Loading friends...")
                } else if viewModel.friends.isEmpty {
                    emptyView
                } else {
                    friendsList
                }
            }
            .navigationTitle("Friends")
            .refreshable {
                await viewModel.loadFriends()
            }
            .sheet(item: $selectedFriend) { friend in
                FriendDetailSheet(friend: friend) {
                    Task {
                        await viewModel.removeFriend(friend)
                        selectedFriend = nil
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    private var friendsList: some View {
        List {
            ForEach(viewModel.friends) { friend in
                FriendRowView(friend: friend)
                    .onTapGesture {
                        selectedFriend = friend
                    }
            }
        }
        .listStyle(.plain)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Friends Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start connecting with people\non the Discover tab!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
