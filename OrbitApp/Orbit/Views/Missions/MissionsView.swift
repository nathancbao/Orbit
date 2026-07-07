import SwiftUI

// MARK: - Hour Slot Key

struct HourSlotKey: Hashable {
    let dayOffset: Int
    let hour: Int
}

// MARK: - Missions View
// Unified discover feed for both Set (fixed-date) and Flex (group-picks-time) missions.

struct MissionsView: View {
    @Binding var userProfile: Profile
    @StateObject private var viewModel = MissionsViewModel()
    @State private var selectedMission: Mission?
    @State private var showCreate = false
    @State private var showProfile = false
    @State private var createdFlexPodId: String? = nil
    @State private var showCreatedFlexPod = false
    @State private var searchText = ""
    @State private var showFilterSheet = false
    @State private var podToOpen: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemBackground).ignoresSafeArea()
                OrbitRingsBackground()
                FloatingCurvesBackground()

                VStack(spacing: 0) {
                    // Search bar + filter button
                    HStack(spacing: 10) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search missions", text: $searchText)
                        }
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showFilterSheet = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .orbitFont(18, weight: .semibold)
                                .foregroundColor(viewModel.hasActiveFilter ? .white : .primary)
                                .frame(width: 42, height: 42)
                                .background(
                                    viewModel.hasActiveFilter
                                        ? AnyShapeStyle(OrbitTheme.gradientFill)
                                        : AnyShapeStyle(Color(.systemGray6))
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Missions List
                            if viewModel.isLoading && viewModel.allMissions.isEmpty {
                                HStack { Spacer(); ProgressView(); Spacer() }
                                    .padding(.vertical, 40)
                            } else {
                                let displayedMissions = searchText.isEmpty
                                    ? viewModel.discoverMissions
                                    : viewModel.discoverMissions.filter {
                                        $0.title.localizedCaseInsensitiveContains(searchText)
                                        || $0.displayTitle.localizedCaseInsensitiveContains(searchText)
                                    }

                                if displayedMissions.isEmpty {
                                    EmptyMissionsView(onCreateTap: { showCreate = true })
                                        .padding(.horizontal, 20)
                                } else {
                                    VStack(spacing: 14) {
                                        ForEach(displayedMissions) { mission in
                                            MissionListCard(
                                                mission: mission,
                                                userInterests: userProfile.interests,
                                                onTap: { selectedMission = mission },
                                                onOpenPod: { podId in podToOpen = podId }
                                            )
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
                            .orbitFont(18, weight: .bold)
                        Text("Create")
                            .orbitFont(16, weight: .semibold)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showProfile = true } label: {
                        ProfileAvatarView(photo: userProfile.photo, size: 34, name: userProfile.name)
                    }
                }
            }
        }
        .sheet(item: $selectedMission, onDismiss: {
            Task { await viewModel.reload() }
        }) { mission in
            MissionDetailView(mission: mission, viewModel: viewModel, onJoined: {
                selectedMission = nil
            })
        }
        .sheet(isPresented: $showFilterSheet) {
            MissionFilterSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: Binding(
            get: { podToOpen.map { IdentifiablePodID(id: $0) } },
            set: { podToOpen = $0?.id }
        )) { wrapper in
            PodView(podId: wrapper.id, title: "Mission", missionMode: .flex)
        }
        .sheet(isPresented: $showCreate) {
            MissionCreateView(
                viewModel: viewModel,
                onCreated: { mission in
                    viewModel.insertCreatedMission(mission)
                    if mission.isFlexMode, let podId = mission.podId {
                        createdFlexPodId = podId
                        showCreatedFlexPod = true
                    }
                }
            )
        }
        .sheet(isPresented: $showCreatedFlexPod) {
            if let podId = createdFlexPodId {
                PodView(podId: podId, title: "New Mission", missionMode: .flex)
            }
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
        .orbitAnimation(.spring(duration: 0.3), value: viewModel.showToast)
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

// MARK: - Mission List Card

struct MissionListCard: View {
    let mission: Mission
    var userInterests: [String] = []
    let onTap: () -> Void
    var onOpenPod: ((String) -> Void)? = nil

    private var lowerInterests: Set<String> {
        Set(userInterests.map { $0.lowercased() })
    }

    /// Subtitle line: a confirmed/fixed time, or the scheduling summary.
    private var subtitle: String {
        if mission.isFlexMode {
            if let t = mission.scheduledTime { return t }
            if let summary = mission.flexAvailabilitySummary { return summary }
            return "Schedule together"
        }
        return mission.displayDate.isEmpty ? "Time TBD" : mission.displayDate
    }

    private var subtitleIcon: String {
        if mission.isFlexMode {
            return mission.scheduledTime != nil ? "calendar.badge.checkmark" : "calendar.badge.clock"
        }
        return "calendar"
    }

    /// A mission is "scheduled" when it has a locked-in time: set missions always
    /// do, flex missions only once the group has picked a time.
    private var isScheduled: Bool {
        mission.isFlexMode ? mission.scheduledTime != nil : true
    }

    /// Scheduled missions get the darker card; missions still being scheduled
    /// (flex, no time yet) get a lighter one.
    private var cardBackground: LinearGradient {
        isScheduled ? OrbitTheme.cardGradient : OrbitTheme.cardGradientScheduling
    }

    /// Uppercase eyebrow describing the scheduling style + state.
    private var eyebrow: String {
        if !mission.isFlexMode { return "SET · FIXED TIME" }
        return isScheduled ? "FLEX · TIME LOCKED" : "FLEX · GROUP PICKS TIME"
    }

    /// Whether the signed-in user created this mission (→ pod leader).
    private var isCreator: Bool {
        guard let creatorId = mission.creatorId else { return false }
        let uid = UserDefaults.standard.integer(forKey: "orbit_user_id")
        return uid != 0 && creatorId == uid
    }

    /// Allowed group-size range, e.g. "3 to 5".
    private var sizeRangeText: String {
        let maxSize = capacity
        if let min = mission.effectiveMinPodSize, min < maxSize {
            return "\(min) to \(maxSize)"
        }
        return "\(maxSize)"
    }

    /// Open-spot summary, e.g. "1 open spot" / "3 open spots" / "full".
    private var openSpotsText: String {
        let spots = displayPod?.spotsLeft ?? max(0, capacity - memberCount)
        if spots == 0 { return "full" }
        return "\(spots) open spot\(spots == 1 ? "" : "s")"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                missionLogo

                VStack(alignment: .leading, spacing: 7) {
                    // Mode eyebrow — uppercase, tracked, gradient accent
                    Text(eyebrow)
                        .orbitFont(10, weight: .heavy, design: .rounded)
                        .tracking(1.4)
                        .foregroundStyle(OrbitTheme.gradient)

                    // Title — rounded display weight for a bolder, less "default" feel
                    Text(mission.displayTitle)
                        .orbitFont(19, weight: .bold, design: .rounded)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Time / schedule line — monospaced for typographic contrast
                    HStack(spacing: 5) {
                        Image(systemName: subtitleIcon)
                            .font(.caption2)
                        Text(subtitle)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white.opacity(0.72))
                    .padding(.top, 1)

                    // Tag chips with consistent per-tag colors
                    if !mission.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(mission.tags.prefix(4), id: \.self) { tag in
                                    let matches = lowerInterests.contains(tag.lowercased())
                                    let color = OrbitTheme.color(forTag: tag, matchesUser: matches)
                                    Text(tag.lowercased())
                                        .orbitFont(11, weight: matches ? .bold : .medium, design: .rounded)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background((matches ? color : Color.white).opacity(matches ? 0.22 : 0.1))
                                        .clipShape(Capsule())
                                        .foregroundColor(matches ? color : .white.opacity(0.8))
                                }
                            }
                        }
                    }

                    // People count + match + joined indicator
                    HStack(spacing: 10) {
                        peopleCountLabel
                        if mission.isJoined {
                            joinedBadge
                        } else if let score = mission.matchScore, score > 0 {
                            MatchScoreBadge(score: score)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 2)
                }
                // Reserve room so a long title never slides under the leader badge.
                .padding(.trailing, isCreator ? 26 : 0)

                Spacer(minLength: 0)
            }
            .padding(18)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        mission.isJoined
                            ? AnyShapeStyle(OrbitTheme.gradient)
                            : AnyShapeStyle(Color.white.opacity(0.08)),
                        lineWidth: mission.isJoined ? 2 : 1
                    )
            )
            // Pod-leader astronaut helmet — only on missions you created.
            .overlay(alignment: .topTrailing) {
                if isCreator {
                    PodLeaderBadge()
                        .padding(12)
                }
            }
            .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 5)
            .opacity(mission.isCompleted ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logo

    private var missionLogo: some View {
        ZStack {
            Circle()
                .fill(OrbitTheme.gradientFill.opacity(0.28))
                .frame(width: 50, height: 50)
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                .frame(width: 50, height: 50)
            Image(systemName: mission.logo ?? "sparkles")
                .orbitFont(21, weight: .semibold)
                .foregroundColor(.white)
        }
    }

    // MARK: - People Count

    private var memberCount: Int {
        displayPod?.memberCount ?? (mission.isJoined ? 1 : 0)
    }

    private var capacity: Int {
        max(displayPod?.maxSize ?? 0, mission.maxPodSize)
    }

    private var peopleCountLabel: some View {
        HStack(spacing: 6) {
            // Overlapping avatar stack
            if !podPreviews.isEmpty {
                HStack(spacing: -6) {
                    ForEach(Array(podPreviews.prefix(3).enumerated()), id: \.element.id) { index, member in
                        ProfileAvatarView(photo: member.photo, size: 20)
                            .zIndex(Double(3 - index))
                    }
                }
            } else {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            // Allowed group-size range, e.g. "3 to 5"
            Text(sizeRangeText)
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.85))
            // Remaining capacity, e.g. "· 1 open spot"
            Text("· \(openSpotsText)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(openSpotsText == "full" ? .white.opacity(0.45) : OrbitTheme.pink)
        }
    }

    /// "· in" badge shown when the user is in this mission's pod. Tappable to
    /// jump straight into the pod.
    private var joinedBadge: some View {
        Button {
            if let podId = mission.userPodId ?? mission.podId {
                onOpenPod?(podId)
            } else {
                onTap()
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                Text("In")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.18))
            .foregroundColor(.green)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pod Member Display

    /// The pod to display: user's pod if joined, otherwise first open pod.
    private var displayPod: PodSummary? {
        guard let pods = mission.pods, !pods.isEmpty else { return nil }
        if let userPodId = mission.userPodId,
           let userPod = pods.first(where: { $0.podId == userPodId }) {
            return userPod
        }
        return pods.first(where: { $0.status == "open" }) ?? pods.first
    }

    private var podPreviews: [MemberPreview] {
        displayPod?.memberPreviews ?? []
    }
}

// MARK: - Pod Leader Badge (gradient astronaut helmet)
// SF Symbols has no astronaut helmet, so we compose one: a gradient dome with a
// dark visor and a glint. Shown on the top-right of missions you created.

struct PodLeaderBadge: View {
    private let visorColor = Color(red: 0.09, green: 0.09, blue: 0.20)

    var body: some View {
        ZStack {
            // Backing ring so the helmet reads on any card shade
            Circle()
                .fill(visorColor)
                .frame(width: 30, height: 30)

            // Helmet dome
            Circle()
                .fill(OrbitTheme.gradientFill)
                .frame(width: 26, height: 26)

            // Visor (dark glass)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(visorColor.opacity(0.92))
                .frame(width: 15, height: 11)
                .offset(y: 1.5)

            // Visor glint
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color.white.opacity(0.55))
                .frame(width: 3.5, height: 3)
                .offset(x: -3, y: -0.5)
        }
        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
        .accessibilityLabel("You're the pod leader")
    }
}

// MARK: - Floating Curves Background
// A handful of gradient "squiggle" curves drifting slowly near the screen edges.
// Low opacity + slow motion keep it ambient rather than distracting.

struct FloatingCurvesBackground: View {
    private struct CurveSpec: Identifiable {
        let id = UUID()
        let asset: String
        let unitX: CGFloat      // 0…1 position across the screen
        let unitY: CGFloat
        let widthFraction: CGFloat
        let rotation: Double
        let opacity: Double
        let drift: CGSize       // half-amplitude of the slow drift
        let duration: Double
    }

    // Generated once per view instance (SwiftUI keeps the first @State value),
    // so positions stay put across re-renders but vary between launches.
    @State private var curves: [CurveSpec] = FloatingCurvesBackground.generate()
    @State private var animate = false

    private static func generate() -> [CurveSpec] {
        let assets = ["squiggle2", "squiggle3", "squiggle4"]
        // 4 curves, each pinned toward an edge so the center stays clear.
        let edgeAnchors: [(CGFloat, CGFloat)] = [
            (CGFloat.random(in: 0.02...0.18), CGFloat.random(in: 0.05...0.30)),   // top-left
            (CGFloat.random(in: 0.82...0.98), CGFloat.random(in: 0.10...0.35)),   // top-right
            (CGFloat.random(in: 0.04...0.20), CGFloat.random(in: 0.70...0.92)),   // bottom-left
            (CGFloat.random(in: 0.80...0.96), CGFloat.random(in: 0.68...0.90))    // bottom-right
        ]
        return edgeAnchors.map { anchor in
            CurveSpec(
                asset: assets.randomElement() ?? "squiggle2",
                unitX: anchor.0,
                unitY: anchor.1,
                widthFraction: CGFloat.random(in: 0.34...0.52),
                rotation: Double.random(in: -35...35),
                opacity: Double.random(in: 0.05...0.10),
                drift: CGSize(width: CGFloat.random(in: 6...16), height: CGFloat.random(in: 8...20)),
                duration: Double.random(in: 7...12)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(curves) { curve in
                    Image(curve.asset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width * curve.widthFraction)
                        .rotationEffect(.degrees(curve.rotation))
                        .opacity(curve.opacity)
                        .position(x: geo.size.width * curve.unitX,
                                  y: geo.size.height * curve.unitY)
                        .offset(x: animate ? curve.drift.width : -curve.drift.width,
                                y: animate ? curve.drift.height : -curve.drift.height)
                        .animation(
                            .easeInOut(duration: curve.duration).repeatForever(autoreverses: true),
                            value: animate
                        )
                }
            }
            .blur(radius: 0.5)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear { animate = true }
    }
}

// MARK: - Orbit Rings Background
// A single large "ringStars" graphic that slowly spins in one direction and
// drifts a little — fainter than the squiggles, sitting deepest for depth.
// Template-rendered + tinted so it reads in both light and dark mode.

struct OrbitRingsBackground: View {
    @State private var spin = false
    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            Image("ringStars")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: geo.size.width * 1.25)
                .foregroundColor(OrbitTheme.purple)
                .opacity(0.045)
                // Anchored toward the upper-right, bleeding off the corner.
                .position(x: geo.size.width * 0.80, y: geo.size.height * 0.20)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .offset(x: drift ? 20 : -20, y: drift ? 16 : -16)
                .orbitAnimation(.linear(duration: 130).repeatForever(autoreverses: false), value: spin)
                .orbitAnimation(.easeInOut(duration: 28).repeatForever(autoreverses: true), value: drift)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            spin = true
            drift = true
        }
    }
}

// MARK: - Flex Status Badge

struct FlexStatusBadge: View {
    let status: SignalStatus

    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .active:  return .green
        }
    }

    var body: some View {
        Text(status.label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.25))
            .clipShape(Capsule())
            .foregroundColor(statusColor)
    }
}

// MARK: - Match Score Badge

struct MatchScoreBadge: View {
    let score: Double

    private var color: Color {
        score >= 0.85 ? .green : score >= 0.70 ? .orange : Color(.systemGray2)
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
            if mission.isCompleted {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Mission completed", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.secondary)
                    if let countdown = mission.deletionCountdownString {
                        Text("Removed in \(countdown)")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            } else {
                switch mission.userPodStatus {
                case "in_pod":
                    Label("You're In!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                default:
                    if let pods = mission.pods, !pods.isEmpty {
                        let open = pods.filter { $0.status != "full" && $0.spotsLeft > 0 }
                        if let first = open.first {
                            Label(
                                "\(first.spotsLeft) spot\(first.spotsLeft == 1 ? "" : "s") left",
                                systemImage: "person.badge.plus"
                            )
                            .foregroundStyle(OrbitTheme.gradient)
                        } else {
                            Label("Join Waitlist", systemImage: "person.badge.clock")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .font(.caption)
        .fontWeight(.medium)
    }
}

// MARK: - Pod ID Wrapper (for item-based sheet)

struct IdentifiablePodID: Identifiable {
    let id: String
}

// MARK: - Mission Filter Sheet

struct MissionFilterSheet: View {
    @ObservedObject var viewModel: MissionsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort by") {
                    ForEach(MissionSort.allCases) { option in
                        Button {
                            viewModel.sort = option
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundStyle(OrbitTheme.gradient)
                                    .frame(width: 24)
                                Text(option.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.sort == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(OrbitTheme.gradient)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }

                Section("Filter") {
                    Toggle(isOn: $viewModel.createdByMeOnly) {
                        Label("Created by me", systemImage: "person.crop.circle")
                    }

                    Picker(selection: Binding(
                        get: { viewModel.filterTag ?? "" },
                        set: { viewModel.filterTag = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Any tag").tag("")
                        ForEach(viewModel.availableTags, id: \.self) { tag in
                            Text(tag.capitalized).tag(tag)
                        }
                    } label: {
                        Label("Tag", systemImage: "tag")
                    }
                }

                if viewModel.hasActiveFilter {
                    Section {
                        Button(role: .destructive) {
                            viewModel.sort = .bestMatch
                            viewModel.createdByMeOnly = false
                            viewModel.filterTag = nil
                        } label: {
                            Text("Reset filters")
                        }
                    }
                }
            }
            .navigationTitle("Sort & Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
    var onCreateTap: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "paperplane")
                .orbitFont(48)
                .foregroundStyle(OrbitTheme.gradient)
            Text("no missions yet")
                .font(.headline)
            Text("be the first \u{2014} create a mission for others to join")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if let onCreateTap {
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
    @State private var minPodSize = 3
    @State private var maxPodSize = 4
    @State private var hasEndTime = false   // set mode: end time is optional

    // Flex mode fields
    @State private var minGroupSize = 3
    @State private var maxGroupSize = 10
    @State private var schedulingWindowDays = 7   // today … +14d; default 1 week

    // Images (up to 3, shared) — existing URLs (edit) + newly picked
    @State private var existingImageUrls: [String] = []
    @State private var pickedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var showAvailabilityPicker = false
    @State private var selectedDays: Set<Int> = []
    @State private var selectedHours: Set<HourSlotKey> = []
    @State private var timeRangeStart: Int = 9
    @State private var timeRangeEnd: Int = 21
    // Optional links (both modes, max 3) — fields appear one at a time via a + button
    @State private var links: [String] = []

    // Creator availability (flex mode — filled during creation)
    @State private var creatorSlots: Set<TimeSlot> = []

    @State private var customTagText = ""
    @State private var showLocationSearch = false

    // Logo (SF Symbol) — replaces activity_category
    @State private var selectedLogo: String? = nil
    @State private var showLogoPicker = false

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var onCreated: ((Mission) -> Void)?

    // Edit mode
    var editingMission: Mission?
    var onUpdated: ((Mission) -> Void)?

    private var isEditing: Bool { editingMission != nil }

    private let maxDayOffset = 1

    init(
        viewModel: MissionsViewModel,
        prefillTitle: String = "",
        prefillTags: [String] = [],
        editingMission: Mission? = nil,
        onCreated: ((Mission) -> Void)? = nil,
        onUpdated: ((Mission) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.editingMission = editingMission
        self.onCreated = onCreated
        self.onUpdated = onUpdated

        if let m = editingMission {
            _mode = State(initialValue: m.mode)
            _title = State(initialValue: m.title)
            _description = State(initialValue: m.description)
            _location = State(initialValue: m.location)
            _tags = State(initialValue: m.tags)
            _minPodSize = State(initialValue: m.effectiveMinPodSize ?? 3)
            _maxPodSize = State(initialValue: m.maxPodSize)
            _selectedLogo = State(initialValue: m.logo)
            _existingImageUrls = State(initialValue: m.images ?? [])
            _schedulingWindowDays = State(initialValue: m.schedulingWindowDays ?? 7)
            _hasEndTime = State(initialValue: m.endTime != nil && !(m.endTime?.isEmpty ?? true))

            // Set mode fields
            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "yyyy-MM-dd"
            _date = State(initialValue: dateFmt.date(from: m.date) ?? Date().addingTimeInterval(86400))

            let timeFmt = DateFormatter()
            timeFmt.dateFormat = "HH:mm"
            _startTime = State(initialValue: m.startTime.flatMap { timeFmt.date(from: $0) }
                ?? Calendar.current.date(from: DateComponents(hour: 12, minute: 0))!)
            _endTime = State(initialValue: m.endTime.flatMap { timeFmt.date(from: $0) }
                ?? Calendar.current.date(from: DateComponents(hour: 13, minute: 0))!)

            // Flex mode fields
            _minGroupSize = State(initialValue: m.minGroupSize ?? 3)
            _maxGroupSize = State(initialValue: m.maxPodSize)
            _timeRangeStart = State(initialValue: m.timeRangeStart ?? 9)
            _timeRangeEnd = State(initialValue: m.timeRangeEnd ?? 21)

            _links = State(initialValue: Array((m.links ?? []).prefix(3)))
        } else {
            _title = State(initialValue: prefillTitle)
            _tags = State(initialValue: prefillTags)
        }
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
        if title.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        // Schedule-later missions need the creator's availability before posting.
        if mode == .flex && !isEditing && creatorSlots.isEmpty { return false }
        return true
    }

    private var linksArray: [String] {
        links
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var visibleHours: [Int] {
        guard timeRangeStart < timeRangeEnd else { return [] }
        return Array(timeRangeStart..<timeRangeEnd)
    }

    private var sortedDays: [Int] { selectedDays.sorted() }

    /// Missions can be scheduled today through 2 weeks out — never further.
    private var maxScheduleDate: Date {
        Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    unifiedForm

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
            .navigationTitle(isEditing ? "Edit Mission" : "New Mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showLocationSearch) {
                LocationSearchView(locationName: $location)
            }
            .sheet(isPresented: $showLogoPicker) {
                LogoPickerSheet(selected: $selectedLogo)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showImagePicker) {
                PhotoLibraryPicker(selectedImage: Binding(
                    get: { nil },
                    set: { newImage in
                        if let img = newImage, totalImageCount < 3 {
                            pickedImages.append(img)
                        }
                    }
                ))
            }
            .sheet(isPresented: $showAvailabilityPicker) {
                AvailabilityPickerSheet(
                    selectedSlots: $creatorSlots,
                    startDate: Date(),
                    totalDays: schedulingWindowDays,
                    memberColor: MemberColor.pink.color
                )
            }
        }
    }

    private var totalImageCount: Int { existingImageUrls.count + pickedImages.count }

    // MARK: - Image Picker (shared, up to 3)

    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                OrbitSectionHeader(title: "Photos", optional: true)
                Spacer()
                Text("\(totalImageCount)/3")
                    .font(.caption2)
                    .foregroundColor(totalImageCount >= 3 ? .orange : .secondary)
            }
            Text("Add a flyer or photos so people know what to expect.")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(existingImageUrls.enumerated()), id: \.offset) { index, url in
                        imageThumb(url: url) { existingImageUrls.remove(at: index) }
                    }
                    ForEach(Array(pickedImages.enumerated()), id: \.offset) { index, img in
                        imageThumb(image: img) { pickedImages.remove(at: index) }
                    }
                    if totalImageCount < 3 {
                        Button { showImagePicker = true } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                    .frame(width: 72, height: 72)
                                Image(systemName: "plus")
                                    .font(.title3)
                                    .foregroundStyle(OrbitTheme.gradient)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func imageThumb(url: String? = nil, image: UIImage? = nil, onRemove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if let url, let parsed = URL(string: url) {
                    AsyncImage(url: parsed) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color(.systemGray5)
                    }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .orbitFont(18)
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .offset(x: 6, y: -6)
        }
    }

    // MARK: - Logo Picker (shared)

    private var logoPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrbitSectionHeader(title: "Logo", optional: true)
            Button {
                showLogoPicker = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 52, height: 52)
                        if let logo = selectedLogo {
                            Image(systemName: logo)
                                .orbitFont(22, weight: .medium)
                                .foregroundStyle(OrbitTheme.gradient)
                        } else {
                            Image(systemName: "face.smiling")
                                .orbitFont(22)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text(selectedLogo == nil ? "Choose a logo" : "Tap to change")
                        .font(.subheadline)
                        .foregroundColor(selectedLogo == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tag Picker (shared)

    private let availableTags = ["Hiking", "Gaming", "Food", "Sports", "Study", "Hangout", "Other"]

    private let maxTagCount = 3

    private var tagPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                OrbitSectionHeader(title: "Tags", optional: true)
                Spacer()
                Text("\(tags.count)/\(maxTagCount)")
                    .font(.caption2)
                    .foregroundColor(tags.count >= maxTagCount ? .orange : .secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableTags, id: \.self) { tag in
                        let isSelected = tags.contains(tag)
                        let isDisabled = !isSelected && tags.count >= maxTagCount
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if isSelected {
                                tags.removeAll { $0 == tag }
                            } else if tags.count < maxTagCount {
                                tags.append(tag)
                            }
                        } label: {
                            Text(tag.capitalized)
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
                                .opacity(isDisabled ? 0.4 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDisabled)
                    }
                }
            }
        }
    }

    // MARK: - Unified Form (single page; toggle switches scheduling style)
    // Field order: name, logo (+ photos), description, tags, pod size, location,
    // mission type, time/availability, links.

    private var unifiedForm: some View {
        VStack(spacing: 24) {
            titleField
            logoPickerSection
            imagePickerSection
            descriptionField
            tagPickerSection
            customTagSection
            podSizeSection
            locationSection

            scheduleToggle

            if mode == .set {
                whenSection
            } else {
                schedulingWindowSection
                availabilitySection
            }

            // Links are optional for both set and flex missions — always last.
            linksSection
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            OrbitSectionHeader(title: "Mission name")
            TextField("e.g. Study Time", text: $title)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            OrbitSectionHeader(title: "Description", optional: true)
            TextField("What's this about?", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
            HStack {
                Spacer()
                Text("\(wordCount)/250 words")
                    .font(.caption2)
                    .foregroundColor(isOverWordLimit ? .red : .secondary)
            }
        }
    }

    private var customTagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Add a custom tag", text: $customTagText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit { addCustomTag() }
                    .disabled(tags.count >= maxTagCount)
                Button(action: addCustomTag) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(OrbitTheme.gradient)
                }
                .disabled(customTagText.trimmingCharacters(in: .whitespaces).isEmpty || tags.count >= maxTagCount)
            }

            let customTags = tags.filter { !availableTags.contains($0) }
            if !customTags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(customTags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.caption)
                                .fontWeight(.medium)
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(OrbitTheme.gradient.opacity(0.15))
                        .foregroundColor(OrbitTheme.purple)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var podSizeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrbitSectionHeader(title: "Pod size")
            VStack(spacing: 0) {
                HStack {
                    Label("Min \(minPodSize) people", systemImage: "person.2")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Stepper("", value: $minPodSize, in: 3...maxPodSize)
                        .labelsHidden()
                        .fixedSize()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().padding(.leading, 16)

                HStack {
                    Label("Max \(maxPodSize) people", systemImage: "person.2.fill")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Stepper("", value: $maxPodSize, in: max(3, minPodSize)...10)
                        .labelsHidden()
                        .fixedSize()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("Pods need at least 3 people so no one meets up one-on-one with a stranger.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            OrbitSectionHeader(title: "Location", optional: true)
            if location.isEmpty {
                Button { showLocationSearch = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(OrbitTheme.gradient)
                        Text("Add location")
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(OrbitTheme.gradient)
                    Text(location)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    Spacer()
                    Button { location = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                Button("Change location") { showLocationSearch = true }
                    .font(.subheadline)
                    .foregroundStyle(OrbitTheme.gradient)
            }
        }
    }

    /// The schedule-now-vs-later control: a single switch-style card that lights
    /// up when the group schedules together. When on, the date/time inputs are
    /// replaced by the scheduling window + availability picker.
    private var scheduleToggle: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrbitSectionHeader(title: "Scheduling")
            Button {
                guard !isEditing else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(duration: 0.3)) {
                    mode = (mode == .flex) ? .set : .flex
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.3.sequence.fill")
                        .orbitFont(18)
                        .foregroundColor(mode == .flex ? .white : OrbitTheme.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Schedule as a group")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(mode == .flex ? .white : .primary)
                        Text(mode == .flex
                             ? "Your pod picks a time from everyone's availability."
                             : "Off — you'll set a specific date and time below.")
                            .font(.caption)
                            .foregroundColor(mode == .flex ? .white.opacity(0.85) : .secondary)
                    }
                    Spacer()
                    // Switch-style knob
                    ZStack(alignment: mode == .flex ? .trailing : .leading) {
                        Capsule()
                            .fill(mode == .flex ? AnyShapeStyle(Color.white.opacity(0.5)) : AnyShapeStyle(Color(.systemGray3)))
                            .frame(width: 44, height: 26)
                        Circle()
                            .fill(.white)
                            .frame(width: 22, height: 22)
                            .padding(2)
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    }
                }
                .padding(14)
                .background(
                    mode == .flex
                        ? AnyShapeStyle(OrbitTheme.gradientFill)
                        : AnyShapeStyle(Color(.systemGray6))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .opacity(isEditing ? 0.6 : 1.0)
        }
    }

    /// Set-mode date + time inputs.
    private var whenSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrbitSectionHeader(title: "When")
            VStack(spacing: 0) {
                HStack {
                    Label("Date", systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    DatePicker("", selection: $date, in: Date()...maxScheduleDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().padding(.leading, 16)

                HStack {
                    Label("Starts", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().padding(.leading, 16)

                HStack {
                    Toggle(isOn: $hasEndTime) {
                        Label("Add end time", systemImage: "clock.fill")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .tint(OrbitTheme.purple)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if hasEndTime {
                    Divider().padding(.leading, 16)

                    HStack {
                        Label("Ends", systemImage: "clock.fill")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        DatePicker("", selection: $endTime, in: startTime..., displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("Pick the day and a start time. An end time is optional.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onChange(of: startTime) { _, newStart in
            if endTime <= newStart { endTime = newStart.addingTimeInterval(3600) }
        }
        .onChange(of: endTime) { _, newEnd in
            if newEnd <= startTime { endTime = startTime.addingTimeInterval(3600) }
        }
    }

    /// Flex-mode availability entry: a button that opens the no-scroll picker.
    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrbitSectionHeader(title: "Your availability")
            Button {
                showAvailabilityPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .orbitFont(18)
                        .foregroundStyle(OrbitTheme.gradient)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(creatorSlots.isEmpty ? "Input your availability" : "Edit your availability")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text(creatorSlots.isEmpty
                             ? "Tap to mark the hours you're free"
                             : "\(creatorSlots.count) hour\(creatorSlots.count == 1 ? "" : "s") selected")
                            .font(.caption)
                            .foregroundColor(creatorSlots.isEmpty ? .secondary : OrbitTheme.purple)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(creatorSlots.isEmpty ? Color(.systemGray4) : OrbitTheme.purple.opacity(0.5), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Set Mode Form

    private var setModeForm: some View {
        VStack(alignment: .leading, spacing: 20) {

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

            tagPickerSection

            // Custom tags (set mode only)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Add a custom tag", text: $customTagText)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit { addCustomTag() }
                        .disabled(tags.count >= maxTagCount)
                    Button(action: addCustomTag) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(OrbitTheme.gradient)
                    }
                    .disabled(customTagText.trimmingCharacters(in: .whitespaces).isEmpty || tags.count >= maxTagCount)
                }

                let customTags = tags.filter { !availableTags.contains($0) }
                if !customTags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(customTags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(OrbitTheme.gradient.opacity(0.15))
                            .foregroundColor(OrbitTheme.purple)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Date + Time grouped in a single card
            VStack(alignment: .leading, spacing: 10) {
                OrbitSectionHeader(title: "When")
                VStack(spacing: 0) {
                    HStack {
                        Label("Date", systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        DatePicker("", selection: $date, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    Divider().padding(.leading, 16)

                    HStack {
                        Label("Starts", systemImage: "clock")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    Divider().padding(.leading, 16)

                    HStack {
                        Label("Ends", systemImage: "clock.fill")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        DatePicker("", selection: $endTime, in: startTime..., displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .onChange(of: startTime) { _, newStart in
                if endTime <= newStart {
                    endTime = newStart.addingTimeInterval(3600)
                }
            }
            .onChange(of: endTime) { _, newEnd in
                if newEnd <= startTime {
                    endTime = startTime.addingTimeInterval(3600)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                OrbitSectionHeader(title: "Location (optional)")
                if location.isEmpty {
                    Button { showLocationSearch = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(OrbitTheme.gradient)
                            Text("Add location")
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(OrbitTheme.gradient)
                        Text(location)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        Spacer()
                        Button {
                            location = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    Button("Change location") { showLocationSearch = true }
                        .font(.subheadline)
                        .foregroundStyle(OrbitTheme.gradient)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                OrbitSectionHeader(title: "Pod Size")
                VStack(spacing: 0) {
                    HStack {
                        Label("Min \(minPodSize) people", systemImage: "person.2")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Stepper("", value: $minPodSize, in: 2...maxPodSize)
                            .labelsHidden()
                            .fixedSize()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    Divider().padding(.leading, 16)

                    HStack {
                        Label("Max \(maxPodSize) people", systemImage: "person.2.fill")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Stepper("", value: $maxPodSize, in: minPodSize...10)
                            .labelsHidden()
                            .fixedSize()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
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

            // Tags
            tagPickerSection

            // Custom tags
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Add a custom tag", text: $customTagText)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit { addCustomTag() }
                        .disabled(tags.count >= maxTagCount)
                    Button(action: addCustomTag) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(OrbitTheme.gradient)
                    }
                    .disabled(customTagText.trimmingCharacters(in: .whitespaces).isEmpty || tags.count >= maxTagCount)
                }

                let customTags = tags.filter { !availableTags.contains($0) }
                if !customTags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(customTags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(OrbitTheme.gradient.opacity(0.15))
                            .foregroundColor(OrbitTheme.purple)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Location
            VStack(alignment: .leading, spacing: 8) {
                OrbitSectionHeader(title: "Location (optional)")
                if location.isEmpty {
                    Button { showLocationSearch = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(OrbitTheme.gradient)
                            Text("Add location")
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(OrbitTheme.gradient)
                        Text(location)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        Spacer()
                        Button {
                            location = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    Button("Change location") { showLocationSearch = true }
                        .font(.subheadline)
                        .foregroundStyle(OrbitTheme.gradient)
                }
            }

            // Links
            linksSection

            // Scheduling window
            schedulingWindowSection

            // Creator availability grid
            VStack(alignment: .leading, spacing: 12) {
                OrbitSectionHeader(title: "When are you free?")
                Text("Select the hours you're available — your pod will coordinate around this")
                    .font(.caption)
                    .foregroundColor(.secondary)

                CreatorAvailabilityGridView(
                    selectedSlots: $creatorSlots,
                    startDate: Date(),
                    memberColor: MemberColor.pink.color
                )

                HStack {
                    Text("\(creatorSlots.count) hour\(creatorSlots.count == 1 ? "" : "s") selected")
                        .font(.caption)
                        .foregroundColor(creatorSlots.isEmpty ? .red : .secondary)
                    Spacer()
                    if !creatorSlots.isEmpty {
                        Button("Clear") { creatorSlots.removeAll() }
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
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
                                .orbitFont(12, weight: .semibold)
                            Text(dateLabel(for: offset))
                                .orbitFont(10)
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
                            .orbitFont(11, weight: .medium)
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
                    Stepper("\(maxGroupSize)", value: $maxGroupSize, in: minGroupSize...10)
                        .font(.subheadline)
                }
            }
            Text("\(minGroupSize)\u{2013}\(maxGroupSize) people")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Scheduling Window

    private var schedulingWindowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrbitSectionHeader(title: "Scheduling window")
            HStack {
                Label("Within \(schedulingWindowDays) day\(schedulingWindowDays == 1 ? "" : "s")",
                      systemImage: "calendar.badge.clock")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Stepper("", value: $schedulingWindowDays, in: 1...14)
                    .labelsHidden()
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("Missions can be scheduled from today up to 2 weeks out. Default is 1 week so missions don't linger.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Links
    // Up to 3 links. Fields appear one at a time via a + button so the form
    // doesn't waste space on empty inputs.

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Links", optional: true)

            ForEach(links.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    TextField("Paste a link", text: $links[index])
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        links.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                    .buttonStyle(.plain)
                }
            }

            if links.count < 3 {
                Button {
                    links.append("")
                } label: {
                    Label(links.isEmpty ? "Add a link" : "Add another link",
                          systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(OrbitTheme.gradient)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            submit()
        } label: {
            ZStack {
                if isSubmitting || viewModel.isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text(isEditing ? "Save Changes" : "Create Mission")
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

    // MARK: - Submit

    private func submit() {
        guard canSubmit, !isSubmitting, !viewModel.isSubmitting else { return }
        isSubmitting = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedDesc = description.trimmingCharacters(in: .whitespaces)
        let trimmedLoc = location.trimmingCharacters(in: .whitespaces)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        // Set-mode values (single day, required start, optional end)
        let dateString = dateFormatter.string(from: date)
        let startTimeString = timeFormatter.string(from: startTime)
        let endTimeString: String? = hasEndTime ? timeFormatter.string(from: endTime) : nil

        // Flex-mode placeholder availability — the pod picks the real time later.
        let defaultSlot = AvailabilitySlot(date: Date(), timeBlocks: TimeBlock.allCases, hours: [])
        let slotsToSave = creatorSlots

        Task {
            // 1. Upload any newly-picked images, collect all image URLs.
            var imageUrls = existingImageUrls
            for image in pickedImages {
                if let url = try? await MissionService.shared.uploadMissionImage(image) {
                    imageUrls.append(url)
                }
            }
            imageUrls = Array(imageUrls.prefix(3))

            let minSize = minPodSize
            let maxSize = maxPodSize

            // 2. Create or update via the unified Mission kind.
            let result: Mission?
            if let editing = editingMission {
                result = await viewModel.updateMission(
                    id: editing.id, mode: mode, title: trimmedTitle, description: trimmedDesc,
                    tags: tags, logo: selectedLogo, images: imageUrls,
                    minPodSize: minSize, maxPodSize: maxSize, location: trimmedLoc,
                    date: dateString, startTime: startTimeString, endTime: endTimeString,
                    availability: [defaultSlot], timeRangeStart: timeRangeStart,
                    timeRangeEnd: timeRangeEnd, links: linksArray,
                    schedulingWindowDays: schedulingWindowDays
                )
            } else {
                result = await viewModel.createMission(
                    mode: mode, title: trimmedTitle, description: trimmedDesc,
                    tags: tags, logo: selectedLogo, images: imageUrls,
                    minPodSize: minSize, maxPodSize: maxSize, location: trimmedLoc,
                    date: dateString, startTime: startTimeString, endTime: endTimeString,
                    availability: [defaultSlot], timeRangeStart: timeRangeStart,
                    timeRangeEnd: timeRangeEnd, links: linksArray,
                    schedulingWindowDays: schedulingWindowDays
                )
            }

            await MainActor.run {
                isSubmitting = false
                guard let result else {
                    errorMessage = viewModel.errorMessage ?? "Something went wrong. Try again."
                    return
                }
                // Seed the creator's availability into the pod for flex missions.
                if mode == .flex, editingMission == nil,
                   let podId = result.podId ?? result.userPodId, !slotsToSave.isEmpty {
                    let userId = UserDefaults.standard.integer(forKey: "orbit_user_id")
                    let userName = UserDefaults.standard.string(forKey: "orbit_user_name") ?? "You"
                    ScheduleService.shared.saveAvailability(
                        podId: podId, userId: userId, name: userName, joinIndex: 0, slots: slotsToSave
                    )
                }
                if editingMission != nil {
                    onUpdated?(result)
                } else {
                    onCreated?(result)
                }
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private func addCustomTag() {
        let tag = customTagText.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !tags.contains(tag), tags.count < 3 else { return }
        tags.append(tag)
        customTagText = ""
    }

    private func resetForm() {
        title = ""
        description = ""
        location = ""
        tags = []
        date = Date().addingTimeInterval(86400)
        startTime = Calendar.current.date(from: DateComponents(hour: 12, minute: 0))!
        endTime = Calendar.current.date(from: DateComponents(hour: 13, minute: 0))!
        maxPodSize = 4
        minGroupSize = 3
        maxGroupSize = 10
        creatorSlots = []
        selectedDays = []
        selectedHours = []
        links = []
        customTagText = ""
        errorMessage = nil
    }

    private func hourString(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h)\(hour < 12 ? "am" : "pm")"
    }

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
                .orbitFont(size * 0.4, weight: .semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(OrbitTheme.gradientFill)
        } else {
            Image(systemName: "person.fill")
                .foregroundColor(.secondary)
                .orbitFont(size * 0.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray5))
        }
    }
}

// MARK: - Logo Picker

/// Curated set of activity SF Symbols offered when creating a mission.
let missionLogoOptions: [String] = [
    "figure.run", "figure.hiking", "figure.outdoor.cycle", "sportscourt.fill",
    "basketball.fill", "soccerball", "football.fill", "tennis.racket",
    "dumbbell.fill", "fork.knife", "cup.and.saucer.fill", "wineglass.fill",
    "birthday.cake.fill", "carrot.fill", "film.fill", "tv.fill",
    "music.note", "headphones", "gamecontroller.fill", "book.fill",
    "graduationcap.fill", "pencil.and.ruler.fill", "paintpalette.fill", "camera.fill",
    "person.2.fill", "party.popper.fill", "leaf.fill", "mountain.2.fill",
    "airplane", "cart.fill", "hammer.fill", "theatermasks.fill",
    "pawprint.fill", "gift.fill", "map.fill", "guitars.fill",
    "dice.fill", "puzzlepiece.fill", "globe.americas.fill", "sparkles",
]

struct LogoPickerSheet: View {
    @Binding var selected: String?
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    // Clear / no logo
                    LogoCell(symbol: nil, isSelected: selected == nil) {
                        selected = nil
                        dismiss()
                    }
                    ForEach(missionLogoOptions, id: \.self) { symbol in
                        LogoCell(symbol: symbol, isSelected: selected == symbol) {
                            selected = symbol
                            dismiss()
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Choose a Logo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct LogoCell: View {
    let symbol: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? AnyShapeStyle(OrbitTheme.gradient.opacity(0.18))
                          : AnyShapeStyle(Color(.systemGray6)))
                    .frame(height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected
                                    ? AnyShapeStyle(OrbitTheme.gradient)
                                    : AnyShapeStyle(Color.clear),
                                    lineWidth: 2)
                    )
                if let symbol {
                    Image(systemName: symbol)
                        .orbitFont(24, weight: .medium)
                        .foregroundStyle(isSelected
                                         ? AnyShapeStyle(OrbitTheme.gradient)
                                         : AnyShapeStyle(Color.primary))
                } else {
                    Image(systemName: "nosign")
                        .orbitFont(22)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
