import SwiftUI

// MARK: - Missions View
// Discover feed for fixed-date community missions.

struct MissionsView: View {
    let userProfile: Profile
    @StateObject private var viewModel = MissionsViewModel()
    @State private var selectedMission: Mission?
    @State private var showCreate = false

    private let allTags = [
        "Hiking", "Gaming", "Music", "Food", "Sports",
        "Art", "Coffee", "Tech", "Fitness", "Travel"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Suggested missions strip
                        if !viewModel.suggestedMissions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("suggested for you")
                                    .font(.headline)
                                    .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(viewModel.suggestedMissions) { mission in
                                            SuggestedMissionCard(mission: mission) {
                                                selectedMission = mission
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        // Tag Filters
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                TagFilterChip(label: "all", isSelected: viewModel.filterTag == nil) {
                                    Task { await viewModel.applyTag(nil) }
                                }
                                ForEach(allTags, id: \.self) { tag in
                                    TagFilterChip(
                                        label: tag.lowercased(),
                                        isSelected: viewModel.filterTag == tag
                                    ) {
                                        Task { await viewModel.applyTag(viewModel.filterTag == tag ? nil : tag) }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Missions List
                        if viewModel.isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .padding(.vertical, 40)
                        } else if viewModel.allMissions.isEmpty {
                            EmptyMissionsView()
                                .padding(.horizontal, 20)
                        } else {
                            VStack(spacing: 14) {
                                ForEach(viewModel.allMissions) { mission in
                                    MissionListCard(mission: mission) {
                                        selectedMission = mission
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.top, 16)
                }
                .refreshable {
                    await viewModel.reload()
                }
            }
            .navigationTitle("Missions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await viewModel.toggleYearFilter() }
                    } label: {
                        Label(
                            viewModel.showMyYearOnly ? "My Year" : "All Years",
                            systemImage: viewModel.showMyYearOnly ? "person.fill.checkmark" : "person.2"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            viewModel.showMyYearOnly
                                ? AnyShapeStyle(OrbitTheme.gradient)
                                : AnyShapeStyle(Color.secondary)
                        )
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreate = true } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(OrbitTheme.gradient)
                    }
                }
            }
        }
        .sheet(item: $selectedMission) { mission in
            MissionDetailView(mission: mission, onJoined: {
                Task { await viewModel.reload() }
                selectedMission = nil
            })
        }
        .sheet(isPresented: $showCreate) {
            MissionCreateView()
        }
        .task {
            await viewModel.load(userYear: userProfile.collegeYear)
        }
    }
}

// MARK: - Suggested Mission Card

struct SuggestedMissionCard: View {
    let mission: Mission
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                if let reason = mission.suggestionReason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(OrbitTheme.gradient)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(OrbitTheme.pink.opacity(0.1))
                        .clipShape(Capsule())
                }

                Text(mission.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(mission.displayDate)
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                    Text(mission.location.isEmpty ? "TBD" : mission.location)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)

                MissionSpotsLabel(mission: mission)
            }
            .padding(14)
            .frame(width: 200)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mission List Card

struct MissionListCard: View {
    let mission: Mission
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [OrbitTheme.pink, OrbitTheme.blue],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(mission.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(mission.displayDate)
                                .font(.caption)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.caption2)
                            Text(mission.location.isEmpty ? "TBD" : mission.location)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(.secondary)

                    if !mission.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(mission.tags.prefix(4), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(OrbitTheme.blue.opacity(0.12))
                                        .clipShape(Capsule())
                                        .foregroundColor(OrbitTheme.blue)
                                }
                            }
                        }
                    }

                    MissionSpotsLabel(mission: mission)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mission Spots Label

struct MissionSpotsLabel: View {
    let mission: Mission

    var body: some View {
        Group {
            switch mission.userPodStatus {
            case "in_pod":
                Label("you're in!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case "pod_full":
                Label("pods full", systemImage: "person.fill.xmark")
                    .foregroundColor(.secondary)
            default:
                if let pods = mission.pods, !pods.isEmpty {
                    let open = pods.filter { $0.status == "open" }
                    if let first = open.first {
                        Label(
                            "\(first.spotsLeft) spot\(first.spotsLeft == 1 ? "" : "s") left",
                            systemImage: "person.badge.plus"
                        )
                        .foregroundStyle(OrbitTheme.gradient)
                    } else {
                        Label("join waitlist", systemImage: "person.badge.clock")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Label("be the first to join", systemImage: "star")
                        .foregroundStyle(OrbitTheme.gradient)
                }
            }
        }
        .font(.caption)
        .fontWeight(.medium)
    }
}

// MARK: - Tag Filter Chip

struct TagFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    isSelected
                    ? AnyShapeStyle(OrbitTheme.gradient.opacity(0.2))
                    : AnyShapeStyle(Color(.systemGray6))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                            ? AnyShapeStyle(OrbitTheme.gradient)
                            : AnyShapeStyle(Color.clear),
                            lineWidth: 1.5
                        )
                )
                .clipShape(Capsule())
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty Missions View

struct EmptyMissionsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(OrbitTheme.gradient)
            Text("no missions yet")
                .font(.headline)
            Text("pull down to refresh, or check back later!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Mission Create View

struct MissionCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var date = Date().addingTimeInterval(86400)
    @State private var maxPodSize = 4
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        OrbitSectionHeader(title: "Mission Title")
                        TextField("e.g. MMA Club Meeting", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        OrbitSectionHeader(title: "Description")
                        TextField("What's this about? (optional)", text: $description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        OrbitSectionHeader(title: "Date")
                        DatePicker("", selection: $date, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        OrbitSectionHeader(title: "Location (optional)")
                        TextField("Campus Gym, Off-campus, etc.", text: $location)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        OrbitSectionHeader(title: "Max Pod Size")
                        Stepper("\(maxPodSize) people per pod", value: $maxPodSize, in: 2...10)
                            .font(.subheadline)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button {
                        submitMission()
                    } label: {
                        ZStack {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Text("Create Mission")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            canSubmit
                                ? OrbitTheme.gradientFill
                                : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(canSubmit ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("New Mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submitMission() {
        guard canSubmit else { return }
        isSubmitting = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        Task {
            do {
                _ = try await MissionService.shared.createMission(
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces),
                    tags: [],
                    location: location.trimmingCharacters(in: .whitespaces),
                    date: dateString,
                    maxPodSize: maxPodSize
                )
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
