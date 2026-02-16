//
//  MissionsView.swift
//  Orbit
//
//  Main missions feed with segmented picker and create FAB.
//

import SwiftUI

struct MissionsView: View {
    @EnvironmentObject var viewModel: MissionsViewModel
    @State private var showCreateSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Picker
                Picker("Feed", selection: $viewModel.selectedSegment) {
                    ForEach(MissionFeedSegment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // Content
                if viewModel.isLoading && viewModel.currentMissions.isEmpty {
                    Spacer()
                    ProgressView("Loading missions...")
                    Spacer()
                } else if viewModel.currentMissions.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.currentMissions) { mission in
                                NavigationLink(destination: MissionDetailView(mission: mission)) {
                                    MissionCardView(
                                        mission: mission,
                                        userRsvpType: viewModel.getUserRsvpType(missionId: mission.id),
                                        isCreator: viewModel.isCreator(mission)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.loadAll()
                    }
                }
            }
            .navigationTitle("Missions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                MissionFormView(mode: .create)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Something went wrong")
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.successMessage ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(viewModel.selectedSegment == .discover
                 ? "No missions yet"
                 : "You haven't joined any missions")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(viewModel.selectedSegment == .discover
                 ? "Be the first to create one!"
                 : "Discover and join missions to see them here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
