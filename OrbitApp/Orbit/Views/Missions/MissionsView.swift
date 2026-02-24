import SwiftUI

struct MissionsView: View {
    @StateObject private var viewModel = MissionsViewModel()
    @State private var selectedCategory: ActivityCategory?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if viewModel.isLoading && viewModel.missions.isEmpty {
                    ProgressView()
                        .tint(OrbitTheme.purple)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 28) {
                            activityGrid
                            myMissionsSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        viewModel.missions = []
                        viewModel.loadMissions()
                    }
                }
            }
            .navigationTitle("Missions")
            .navigationBarTitleDisplayMode(.large)
            .overlay(alignment: .bottom) {
                if viewModel.showToast {
                    toastView
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: viewModel.showToast)
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Something went wrong")
            }
            .sheet(item: $selectedCategory) { category in
                MissionFormView(category: category)
                    .environmentObject(viewModel)
            }
        }
        .task {
            viewModel.loadMissions()
        }
    }

    // MARK: - Activity Grid

    private var activityGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            OrbitSectionHeader(title: "Pick your mission!")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(ActivityCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.title3)
                            Text(category.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - My Missions

    private var myMissionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            OrbitSectionHeader(title: "My Missions")

            // Pending
            VStack(alignment: .leading, spacing: 12) {
                Text("Searching for Crew...")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                if viewModel.pendingMissions.isEmpty {
                    sectionEmptyState(
                        icon: "clock.arrow.circlepath",
                        message: "No pending missions",
                        detail: "Tap an activity above to get started"
                    )
                } else {
                    ForEach(viewModel.pendingMissions) { mission in
                        missionCard(mission: mission)
                    }
                }
            }

            // Matched
            VStack(alignment: .leading, spacing: 12) {
                Text("Matched Crews")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                if viewModel.matchedMissions.isEmpty {
                    sectionEmptyState(
                        icon: "person.3.fill",
                        message: "No matches yet",
                        detail: "We'll notify you when a crew is found"
                    )
                } else {
                    ForEach(viewModel.matchedMissions) { mission in
                        missionCard(mission: mission)
                    }
                }
            }
        }
    }

    // MARK: - Mission Card

    private func missionCard(mission: Mission) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            OrbitTheme.gradientFill
                .frame(height: 4)

            VStack(alignment: .leading, spacing: 10) {
                // Title row
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: mission.activityCategory.icon)
                        .font(.title3)
                        .foregroundStyle(OrbitTheme.gradient)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(mission.displayTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(2)

                        Text(mission.activityCategory == .custom ? "Custom" : mission.activityCategory.displayName)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    statusBadge(for: mission.status)
                }

                // Availability
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(mission.availabilitySummary)
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.7))

                // Group size
                HStack(spacing: 5) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text(mission.groupSizeLabel)
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.7))

                // Description preview
                if !mission.description.isEmpty {
                    Text(mission.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(2)
                }
            }
            .padding(14)
        }
        .background(OrbitTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Status Badge

    private func statusBadge(for status: MissionStatus) -> some View {
        Text(status.label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                status == .pendingMatch
                    ? OrbitTheme.purple.opacity(0.85)
                    : OrbitTheme.blue.opacity(0.85)
            )
            .clipShape(Capsule())
            .foregroundColor(.white)
    }

    // MARK: - Section Empty State

    private func sectionEmptyState(icon: String, message: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(OrbitTheme.gradient)
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Toast

    private var toastView: some View {
        Text(viewModel.toastMessage ?? "")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.22).opacity(0.95))
            )
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }
}
