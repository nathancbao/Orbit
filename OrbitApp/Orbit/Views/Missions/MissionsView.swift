import SwiftUI

// MARK: - Missions View
// Unified discover feed for both Set (fixed-date) and Flex (group-picks-time) missions.

struct MissionsView: View {
    @Binding var userProfile: Profile
    @StateObject private var viewModel = MissionsViewModel()
    @State private var segment: MissionSegment = .discover
    @State private var selectedMission: Mission?
    @State private var showCreate = false
    @State private var showProfile = false

    private let allTags = [
        "Hiking", "Gaming", "Music", "Food", "Sports",
        "Art", "Coffee", "Tech", "Fitness", "Travel"
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segment picker
                    Picker("", selection: $segment) {
                        ForEach(MissionSegment.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if segment == .discover {
                                // Suggested missions strip (Discover only)
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

                                // Tag Filters (Discover only)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        TagFilterChip(label: "all", isSelected: viewModel.filterTag == nil && !viewModel.showMyYearOnly) {
                                            Task {
                                                if viewModel.showMyYearOnly { await viewModel.toggleYearFilter() }
                                                await viewModel.applyTag(nil)
                                            }
                                        }
                                        TagFilterChip(label: "my year", isSelected: viewModel.showMyYearOnly) {
                                            Task { await viewModel.toggleYearFilter() }
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

                                // Mode filter chips
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        TagFilterChip(label: "all types", isSelected: viewModel.filterMode == nil) {
                                            viewModel.applyModeFilter(nil)
                                        }
                                        TagFilterChip(label: "set", isSelected: viewModel.filterMode == .set) {
                                            viewModel.applyModeFilter(viewModel.filterMode == .set ? nil : .set)
                                        }
                                        TagFilterChip(label: "flex", isSelected: viewModel.filterMode == .flex) {
                                            viewModel.applyModeFilter(viewModel.filterMode == .flex ? nil : .flex)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }

                            // Missions List
                            if viewModel.isLoading {
                                HStack { Spacer(); ProgressView(); Spacer() }
                                    .padding(.vertical, 40)
                            } else {
                                let displayedMissions = segment == .discover
                                    ? viewModel.discoverMissions
                                    : viewModel.myMissions

                                if displayedMissions.isEmpty {
                                    EmptyMissionsView(segment: segment, onCreateTap: { showCreate = true })
                                        .padding(.horizontal, 20)
                                } else {
                                    VStack(spacing: 14) {
                                        ForEach(displayedMissions) { mission in
                                            MissionListCard(mission: mission) {
                                                selectedMission = mission
                                            }
                                            .padding(.horizontal, 20)
                                        }
                                    }
                                }
                            }

                            Spacer(minLength: 100)
                        }
                        .padding(.top, 16)
                    }
                    .refreshable {
                        await viewModel.reload()
                    }
                }

                // FAB — create mission
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showCreate = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                        Text("Create")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(OrbitTheme.gradientFill)
                    .clipShape(Capsule())
                    .shadow(color: OrbitTheme.purple.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("Missions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { } label: {
                        Image(systemName: "bell")
                            .fontWeight(.medium)
                            .foregroundStyle(Color.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showProfile = true } label: {
                        ProfileAvatarView(photo: userProfile.photo, size: 30, name: userProfile.name)
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
            MissionCreateView(
                viewModel: viewModel,
                onCreated: { mission in
                    viewModel.insertCreatedMission(mission)
                    segment = .mine
                }
            )
        }
        .sheet(isPresented: $showProfile) {
            ProfileDisplayView(
                profile: userProfile,
                onEdit: { showProfile = false },
                onProfileUpdated: { updated in userProfile = updated }
            )
        }
        .overlay(alignment: .bottom) {
            if viewModel.showToast {
                toastView
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: viewModel.showToast)
        .task {
            await viewModel.load(userYear: userProfile.collegeYear)
        }
        .onAppear {
            if viewModel.allMissions.isEmpty && !viewModel.isLoading {
                Task { await viewModel.load(userYear: userProfile.collegeYear) }
            }
        }
    }

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

// MARK: - Suggested Mission Card

struct SuggestedMissionCard: View {
    let mission: Mission
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // AI reason — the key value-add
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text(mission.suggestionReason ?? "picked for you")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .foregroundStyle(OrbitTheme.gradient)

                Text(mission.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Label(mission.displayDate, systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                MissionSpotsLabel(mission: mission)
            }
            .padding(16)
            .frame(width: 190)
            .background(
                LinearGradient(
                    colors: [OrbitTheme.pink.opacity(0.07), OrbitTheme.blue.opacity(0.07)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(OrbitTheme.purple.opacity(0.15), lineWidth: 1)
            )
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
                            colors: mission.isFlexMode
                                ? [OrbitTheme.purple, OrbitTheme.pink]
                                : [OrbitTheme.pink, OrbitTheme.blue],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(mission.isFlexMode ? mission.displayTitle : mission.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    if mission.isFlexMode {
                        // Flex mode info
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.caption2)
                                Text("Flex \u{00B7} group picks time")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.secondary)

                        if let summary = mission.flexAvailabilitySummary {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text(summary)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }

                        if let cat = mission.activityCategory {
                            HStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.caption2)
                                Text(cat.displayName)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }

                        HStack(spacing: 8) {
                            if let label = mission.flexGroupSizeLabel {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption2)
                                    Text(label)
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            }
                            if let status = mission.signalStatus {
                                FlexStatusBadge(status: status)
                            }
                        }
                    } else {
                        // Set mode info (unchanged)
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

                        HStack(spacing: 8) {
                            MissionSpotsLabel(mission: mission)
                            if let score = mission.matchScore {
                                MatchScoreBadge(score: score)
                            }
                        }
                    }
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

// MARK: - Flex Status Badge

struct FlexStatusBadge: View {
    let status: SignalStatus

    var body: some View {
        Text(status.label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                status == .pending
                    ? OrbitTheme.purple.opacity(0.15)
                    : OrbitTheme.blue.opacity(0.15)
            )
            .clipShape(Capsule())
            .foregroundColor(status == .pending ? OrbitTheme.purple : OrbitTheme.blue)
    }
}

// MARK: - Match Score Badge

struct MatchScoreBadge: View {
    let score: Double

    private var color: Color {
        score >= 0.75 ? .green : score >= 0.45 ? .orange : Color(.systemGray2)
    }

    var body: some View {
        Text("\(Int(score * 100))% match")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
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
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
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
    var segment: MissionSegment = .discover
    var onCreateTap: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: segment == .discover ? "paperplane" : "tray")
                .font(.system(size: 48))
                .foregroundStyle(OrbitTheme.gradient)
            Text(segment == .discover ? "no missions yet" : "no missions joined")
                .font(.headline)
            Text(segment == .discover
                 ? "be the first \u{2014} create a mission for others to join"
                 : "discover and join missions to see them here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if let onCreateTap, segment == .discover {
                Button(action: onCreateTap) {
                    Label("Create a Mission", systemImage: "plus")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(OrbitTheme.gradientFill)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Mission Create View (Unified: Set + Flex)

struct MissionCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MissionsViewModel

    // Mode toggle
    @State private var mode: MissionMode = .set

    // Shared fields
    @State private var title: String
    @State private var description = ""
    @State private var location = ""
    @State private var tags: [String]

    // Set mode fields
    @State private var date = Date().addingTimeInterval(86400)
    @State private var startTime = Calendar.current.date(from: DateComponents(hour: 12, minute: 0))!
    @State private var endTime = Calendar.current.date(from: DateComponents(hour: 13, minute: 0))!
    @State private var maxPodSize = 4

    // Flex mode fields
    @State private var selectedCategory: ActivityCategory = .hangout
    @State private var customActivityName = ""
    @State private var minGroupSize = 3
    @State private var maxGroupSize = 8
    @State private var selectedDays: Set<Int> = []
    @State private var selectedHours: Set<HourSlotKey> = []
    @State private var timeRangeStart: Int = 9
    @State private var timeRangeEnd: Int = 21
    @State private var link1 = ""
    @State private var link2 = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var onCreated: ((Mission) -> Void)?

    private let maxDayOffset = 1

    init(viewModel: MissionsViewModel, prefillTitle: String = "", prefillTags: [String] = [], onCreated: ((Mission) -> Void)? = nil) {
        self.viewModel = viewModel
        _title = State(initialValue: prefillTitle)
        _tags = State(initialValue: prefillTags)
        self.onCreated = onCreated
    }

    // MARK: - Validation

    private var wordCount: Int {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }

    private var isOverWordLimit: Bool { wordCount > 250 }

    private var canSubmit: Bool {
        if isOverWordLimit { return false }
        if mode == .set {
            return !title.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            if selectedCategory == .custom && customActivityName.trimmingCharacters(in: .whitespaces).isEmpty {
                return false
            }
            return !selectedHours.isEmpty
        }
    }

    private var linksArray: [String] {
        [link1, link2]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var visibleHours: [Int] {
        guard timeRangeStart < timeRangeEnd else { return [] }
        return Array(timeRangeStart..<timeRangeEnd)
    }

    private var sortedDays: [Int] { selectedDays.sorted() }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Mode segmented control
                    Picker("", selection: $mode) {
                        Text("Set").tag(MissionMode.set)
                        Text("Flex").tag(MissionMode.flex)
                    }
                    .pickerStyle(.segmented)

                    if mode == .set {
                        setModeForm
                    } else {
                        flexModeForm
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    submitButton
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

    // MARK: - Set Mode Form

    private var setModeForm: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                OrbitSectionHeader(title: "Mission Title")
                TextField("e.g. BBQ Night", text: $title)
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

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    OrbitSectionHeader(title: "Start Time")
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 8) {
                    OrbitSectionHeader(title: "End Time")
                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
            .onChange(of: startTime) { _, newStart in
                if endTime <= newStart {
                    endTime = newStart.addingTimeInterval(3600)
                }
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
        }
    }

    // MARK: - Flex Mode Form

    private var flexModeForm: some View {
        VStack(spacing: 24) {
            // Title
            VStack(alignment: .leading, spacing: 8) {
                OrbitSectionHeader(title: "Title (optional)")
                TextField("e.g. Pick-up basketball", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            // Category picker
            categorySection

            if selectedCategory == .custom {
                VStack(alignment: .leading, spacing: 8) {
                    OrbitSectionHeader(title: "Activity Name")
                    TextField("Name your activity", text: $customActivityName)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Day picker
            dayPickerSection

            // Time range
            timeRangeSection

            // Hourly grid
            if !selectedDays.isEmpty {
                hourlyGridSection
            }

            // Group size
            groupSizeSection

            // Description
            VStack(alignment: .leading, spacing: 8) {
                OrbitSectionHeader(title: "Description")
                TextField("Describe the activity (optional)", text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...6)
                HStack {
                    Spacer()
                    Text("\(wordCount)/250 words")
                        .font(.caption2)
                        .foregroundColor(isOverWordLimit ? .red : .secondary)
                }
            }

            // Location
            VStack(alignment: .leading, spacing: 8) {
                OrbitSectionHeader(title: "Location (optional)")
                TextField("Campus Gym, Off-campus, etc.", text: $location)
                    .textFieldStyle(.roundedBorder)
            }

            // Links
            linksSection
        }
    }

    // MARK: - Category Picker

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "What do you want to do?")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ActivityCategory.allCases) { category in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedCategory = category
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.title3)
                                Text(category.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                selectedCategory == category
                                    ? AnyShapeStyle(OrbitTheme.gradientFill)
                                    : AnyShapeStyle(Color(.systemGray6))
                            )
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedCategory == category
                                            ? Color.clear
                                            : Color(.systemGray4),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Day Picker

    private var dayPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Which days?")
            Text("Select the days you're available (up to tomorrow)")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(0...maxDayOffset, id: \.self) { offset in
                    let isSelected = selectedDays.contains(offset)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if isSelected {
                            selectedDays.remove(offset)
                            selectedHours = selectedHours.filter { $0.dayOffset != offset }
                        } else {
                            selectedDays.insert(offset)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(dayLabel(for: offset))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(dateLabel(for: offset))
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            isSelected
                                ? AnyShapeStyle(OrbitTheme.gradientFill)
                                : AnyShapeStyle(Color(.systemGray6))
                        )
                        .foregroundColor(isSelected ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isSelected ? Color.clear : Color(.systemGray4),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Time Range

    private var timeRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Time Range")
            Text("Set the window of hours to show")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Start", selection: $timeRangeStart) {
                        ForEach(0..<23, id: \.self) { h in
                            Text(hourString(h)).tag(h)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: timeRangeStart) { _, newVal in
                        if newVal >= timeRangeEnd {
                            timeRangeEnd = min(newVal + 1, 23)
                        }
                        pruneHoursOutsideRange()
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("End")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("End", selection: $timeRangeEnd) {
                        ForEach((timeRangeStart + 1)...23, id: \.self) { h in
                            Text(hourString(h)).tag(h)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: timeRangeEnd) {
                        pruneHoursOutsideRange()
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Hourly Grid

    private var hourlyGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Pick your hours")
            Text("Tap hours you're free \u{2014} \(selectedHours.count) selected")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                // Day column headers
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: 56)
                    ForEach(sortedDays, id: \.self) { offset in
                        VStack(spacing: 2) {
                            Text(dayLabel(for: offset))
                                .font(.system(size: 12, weight: .semibold))
                            Text(dateLabel(for: offset))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 8)

                // Hour rows
                ForEach(visibleHours, id: \.self) { hour in
                    HStack(spacing: 0) {
                        Text(hourString(hour))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 56, alignment: .trailing)
                            .padding(.trailing, 6)

                        ForEach(sortedDays, id: \.self) { dayOffset in
                            let key = HourSlotKey(dayOffset: dayOffset, hour: hour)
                            let isSelected = selectedHours.contains(key)

                            Button {
                                toggleHourSlot(key)
                            } label: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected
                                          ? AnyShapeStyle(OrbitTheme.gradientFill)
                                          : AnyShapeStyle(Color(.systemGray5)))
                                    .frame(height: 36)
                                    .frame(maxWidth: .infinity)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 3)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(12)
            .background(Color(.systemGray6).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button("Select All") {
                    for day in sortedDays {
                        for hour in visibleHours {
                            selectedHours.insert(HourSlotKey(dayOffset: day, hour: hour))
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(OrbitTheme.purple)

                Button("Clear") {
                    selectedHours.removeAll()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Group Size

    private var groupSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Group Size")
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Stepper("\(minGroupSize)", value: $minGroupSize, in: 3...maxGroupSize)
                        .font(.subheadline)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Stepper("\(maxGroupSize)", value: $maxGroupSize, in: minGroupSize...8)
                        .font(.subheadline)
                }
            }
            Text("\(minGroupSize)\u{2013}\(maxGroupSize) people")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Links

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Links (optional)")
            TextField("Paste a link", text: $link1)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Paste a second link", text: $link2)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if mode == .set {
                submitSetMission()
            } else {
                submitFlexMission()
            }
        } label: {
            ZStack {
                if isSubmitting || viewModel.isSubmitting {
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
                canSubmit && !isSubmitting && !viewModel.isSubmitting
                    ? OrbitTheme.gradientFill
                    : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(canSubmit && !isSubmitting && !viewModel.isSubmitting ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canSubmit || isSubmitting || viewModel.isSubmitting)
        .padding(.top, 8)
    }

    // MARK: - Submit Helpers

    private func submitSetMission() {
        guard canSubmit else { return }
        isSubmitting = true
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let startTimeString = timeFormatter.string(from: startTime)
        let endTimeString = timeFormatter.string(from: endTime)

        Task {
            do {
                var created = try await MissionService.shared.createMission(
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces),
                    tags: tags,
                    location: location.trimmingCharacters(in: .whitespaces),
                    date: dateString,
                    startTime: startTimeString,
                    endTime: endTimeString,
                    maxPodSize: maxPodSize
                )
                if let pod = try? await MissionService.shared.joinMission(id: created.id) {
                    created.userPodStatus = "in_pod"
                    created.userPodId = pod.id
                }
                await MainActor.run {
                    isSubmitting = false
                    onCreated?(created)
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

    private func submitFlexMission() {
        guard canSubmit, !viewModel.isSubmitting else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let grouped = Dictionary(grouping: selectedHours) { $0.dayOffset }
        let slots: [AvailabilitySlot] = grouped.keys.sorted().compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { return nil }
            let hours = grouped[dayOffset]!.map(\.hour).sorted()
            return AvailabilitySlot(date: date, hours: hours)
        }

        Task {
            await viewModel.createFlexMission(
                activityCategory: selectedCategory,
                customActivityName: selectedCategory == .custom ? customActivityName.trimmingCharacters(in: .whitespaces) : nil,
                minGroupSize: minGroupSize,
                maxGroupSize: maxGroupSize,
                availability: slots,
                description: description.trimmingCharacters(in: .whitespaces),
                links: linksArray,
                timeRangeStart: timeRangeStart,
                timeRangeEnd: timeRangeEnd
            )
            if viewModel.errorMessage == nil {
                onCreated?(viewModel.allFlexMissions.first ?? Mission(title: ""))
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private func toggleHourSlot(_ key: HourSlotKey) {
        if selectedHours.contains(key) {
            selectedHours.remove(key)
        } else {
            selectedHours.insert(key)
        }
    }

    private func pruneHoursOutsideRange() {
        selectedHours = selectedHours.filter { $0.hour >= timeRangeStart && $0.hour < timeRangeEnd }
    }

    private func dateForOffset(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private func dayLabel(for offset: Int) -> String {
        if offset == 0 { return "Today" }
        if offset == 1 { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: dateForOffset(offset))
    }

    private func dateLabel(for offset: Int) -> String {
        let f = DateFormatter(); f.dateFormat = "M/d"
        return f.string(from: dateForOffset(offset))
    }
}

// MARK: - Profile Avatar View (shared)

struct ProfileAvatarView: View {
    let photo: String?
    let size: CGFloat
    var name: String? = nil

    var body: some View {
        Group {
            if let url = photo, let parsed = URL(string: url) {
                AsyncImage(url: parsed) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
    }

    @ViewBuilder
    private var placeholder: some View {
        if let first = name?.first {
            Text(String(first).uppercased())
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(OrbitTheme.gradientFill)
        } else {
            Image(systemName: "person.fill")
                .foregroundColor(.secondary)
                .font(.system(size: size * 0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray5))
        }
    }
}
