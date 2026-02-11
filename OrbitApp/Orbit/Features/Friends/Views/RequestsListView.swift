//
//  RequestsListView.swift
//  Orbit
//
//  Displays incoming and outgoing friend requests with segmented control.
//

import SwiftUI

struct RequestsListView: View {
    @EnvironmentObject private var viewModel: FriendsViewModel
    @State private var selectedTab: RequestTab = .incoming

    enum RequestTab {
        case incoming
        case outgoing
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented picker
                Picker("Request Type", selection: $selectedTab) {
                    Text("Incoming (\(viewModel.incomingRequests.count))")
                        .tag(RequestTab.incoming)
                    Text("Sent (\(viewModel.outgoingRequests.count))")
                        .tag(RequestTab.outgoing)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                Group {
                    if viewModel.isLoadingRequests && viewModel.incomingRequests.isEmpty && viewModel.outgoingRequests.isEmpty {
                        ProgressView("Loading requests...")
                            .frame(maxHeight: .infinity)
                    } else {
                        switch selectedTab {
                        case .incoming:
                            incomingList
                        case .outgoing:
                            outgoingList
                        }
                    }
                }
            }
            .navigationTitle("Requests")
            .refreshable {
                await viewModel.loadFriendRequests()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") { }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
        }
    }

    private var incomingList: some View {
        Group {
            if viewModel.incomingRequests.isEmpty {
                emptyView(type: .incoming)
            } else {
                List {
                    ForEach(viewModel.incomingRequests) { request in
                        IncomingRequestRowView(
                            request: request,
                            onAccept: {
                                Task { await viewModel.acceptRequest(request) }
                            },
                            onDeny: {
                                Task { await viewModel.denyRequest(request) }
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var outgoingList: some View {
        Group {
            if viewModel.outgoingRequests.isEmpty {
                emptyView(type: .outgoing)
            } else {
                List {
                    ForEach(viewModel.outgoingRequests) { request in
                        OutgoingRequestRowView(
                            request: request,
                            onCancel: {
                                Task { await viewModel.cancelRequest(request) }
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func emptyView(type: RequestTab) -> some View {
        VStack(spacing: 16) {
            Image(systemName: type == .incoming ? "tray" : "paperplane")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text(type == .incoming ? "No Incoming Requests" : "No Sent Requests")
                .font(.title2)
                .fontWeight(.semibold)

            Text(type == .incoming
                 ? "When someone wants to connect,\ntheir request will appear here."
                 : "Requests you send will\nappear here until accepted.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
        .padding()
    }
}
