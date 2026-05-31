//
//  DiscoveryView.swift
//  Orbit
//
//  Galaxy-themed discovery view with image-based stars, comet animation,
//  priority-ring planet layout, motivational banner, and AI recommendation bell.
//

import SwiftUI

// MARK: - Color Palette

enum DiscoveryTheme {
    static let background = Color(hex: "F8F9FC")
    static let surface = Color.white
    static let accentBlue = Color(hex: "3B82F6")
    static let accentTeal = Color(hex: "0D9488")
    static let accentLavender = Color(hex: "8B5CF6")
    static let accentAmber = Color(hex: "D97706")
    static let accentPink = Color(hex: "DB2777")
    static let accentGreen = Color(hex: "059669")
    static let textPrimary = Color(hex: "1E293B")
    static let textMuted = Color(hex: "94A3B8")
    static let glow = Color(hex: "3B82F6").opacity(0.08)

    static let missionColors: [Color] = [accentBlue, accentTeal, accentGreen]
    static let flexColors: [Color] = [accentAmber, accentPink, accentLavender]
    static let templateColor: Color = Color(hex: "6366F1")
}

// MARK: - Color Extension


// MARK: - Image Star Model

struct ImageStar: Identifiable {
    let id = UUID()
    let position: CGPoint       // initial absolute position
    let size: CGFloat           // 14-26pt
    let velocity: CGVector      // constant drift in pt/sec
    let twinkleSpeed: Double
    let phaseOffset: Double
}

// MARK: - Planet Node Model

enum PlanetType {
    case mission(Mission)
    case template(TemplateItem)
}

struct PlanetNode: Identifiable {
    let id: String          // stable — DiscoveryItem.id, so SwiftUI keeps views across refreshes
    let type: PlanetType
    let angle: Double
    let radius: CGFloat
    let accentColor: Color
    let floatPhase: Double
    let floatSpeed: Double
    let priority: Int

    var title: String {
        switch type {
        case .mission(let m): return m.isFlexMode ? m.displayTitle : m.title
        case .template(let t):      return t.title
        }
    }

    var subtitle: String {
        switch type {
        case .mission(let m): return m.isFlexMode ? "flex mission" : m.displayDate
        case .template(let t):      return t.interest
        }
    }

    /// Icon based on the creator-chosen logo. Returns nil when no logo is set,
    /// in which case the planet renders without an icon.
    var activityIcon: String? {
        switch type {
        case .mission(let m):
            guard let logo = m.logo, !logo.isEmpty else { return nil }
            return logo
        case .template:
            return "sparkles"
        }
    }

    /// True once a concrete meeting time exists: a set mission with a date, or a
    /// flex mission whose time has been confirmed. These get the rotating Saturn ring.
    var hasScheduledTime: Bool {
        switch type {
        case .mission(let m):
            return m.mode == .set ? !m.date.isEmpty : (m.scheduledTime != nil)
        case .template:
            return false
        }
    }

    /// True while a flex mission is still being voted on / scheduled. These get the
    /// pulsating ring.
    var isScheduling: Bool {
        switch type {
        case .mission(let m):
            return m.mode == .flex && m.scheduledTime == nil
        case .template:
            return false
        }
    }

    var isTemplate: Bool {
        if case .template = type { return true }
        return false
    }

    var matchScore: Double? {
        if case .mission(let m) = type { return m.matchScore }
        return nil
    }
}

// MARK: - Image Star Field View

struct ImageStarFieldView: View {
    let stars: [ImageStar]
    let size: CGSize

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(stars) { star in
                    let twinkle = (sin(time * star.twinkleSpeed + star.phaseOffset) + 1) / 2
                    let opacity = 0.3 + twinkle * 0.7
                    let pos = drift(star, time: time)

                    Image("blackStar")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: star.size, height: star.size)
                        .opacity(opacity)
                        .position(pos)
                }
            }
        }
    }

    /// Linear drift that wraps around the screen edges (with a margin so a star
    /// fully exits before re-entering from the opposite side).
    private func drift(_ star: ImageStar, time: Double) -> CGPoint {
        let margin: CGFloat = 20
        let wrapW = size.width + margin * 2
        let wrapH = size.height + margin * 2
        guard wrapW > 0, wrapH > 0 else { return star.position }

        let t = CGFloat(time)
        var x = (star.position.x + margin + star.velocity.dx * t)
            .truncatingRemainder(dividingBy: wrapW)
        if x < 0 { x += wrapW }
        var y = (star.position.y + margin + star.velocity.dy * t)
            .truncatingRemainder(dividingBy: wrapH)
        if y < 0 { y += wrapH }
        return CGPoint(x: x - margin, y: y - margin)
    }
}

// MARK: - Comet View

struct CometView: View {
    @State private var cometVisible = false
    @State private var cometOffset: CGFloat = -200
    @State private var cometOpacity: Double = 0

    let screenWidth: CGFloat
    let screenHeight: CGFloat

    var body: some View {
        Image("comet")
            .resizable()
            .renderingMode(.original)
            .frame(width: 60, height: 24)
            .rotationEffect(.degrees(0))
            .opacity(cometOpacity)
            .offset(x: cometOffset, y: cometOffset * 0.5)
            .onAppear {
                scheduleCometStreak()
            }
    }

    private func scheduleCometStreak() {
        let delay = Double.random(in: 12...25)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            fireCometStreak()
        }
    }

    private func fireCometStreak() {
        cometOffset = -200
        cometOpacity = 0.3
        cometVisible = true

        // Fade in
        withAnimation(.easeIn(duration: 0.4)) {
            cometOpacity = 0.9
        }

        // Streak across
        withAnimation(.easeInOut(duration: 2.5)) {
            cometOffset = screenWidth + 200
        }

        // Fade out near end
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                cometOpacity = 0
            }
        }

        // Schedule next
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            scheduleCometStreak()
        }
    }
}

// MARK: - Squiggle Decoration View

struct SquiggleDecorationView: View {
    var body: some View {
        ZStack {
            Image("squiggle2")
                .resizable()
                .renderingMode(.original)
                .frame(width: 120, height: 80)
                .opacity(0.06)
                .offset(x: -80, y: -200)

            Image("squiggle3")
                .resizable()
                .renderingMode(.original)
                .frame(width: 100, height: 70)
                .opacity(0.05)
                .offset(x: 100, y: 220)
        }
    }
}

// MARK: - Motivational Banner View

struct MotivationalBannerView: View {
    @State private var currentIndex = 0

    private let messages = [
        "EXPLORE your universe, find an activity!",
        "What are you in the mood for?",
        "Your orbit is waiting...",
        "Launch into something new today.",
        "Find your people, find your vibe.",
        "Every great adventure starts here.",
        "Your next favorite memory is one tap away."
    ]

    var body: some View {
        Text(messages[currentIndex])
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(DiscoveryTheme.textPrimary)
            .multilineTextAlignment(.center)
            .id(currentIndex)
            .transition(.opacity)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(DiscoveryTheme.surface.opacity(0.92))
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
            )
            .onAppear {
                startCycling()
            }
    }

    private func startCycling() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            withAnimation(.easeInOut(duration: 0.6)) {
                currentIndex = (currentIndex + 1) % messages.count
            }
            startCycling()
        }
    }
}

// MARK: - Recommendation Bell View

struct RecommendationBellView: View {
    let showBadge: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 20))
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary)
                    .frame(width: 34, height: 34)

                if showBadge {
                    Circle()
                        .fill(OrbitTheme.pink)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: 0)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Recommendations Sheet

struct RecommendationsSheet: View {
    let items: [DiscoveryItem]
    let onSelectMission: (Mission) -> Void

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    Text("No recommendations yet. Check back soon!")
                        .foregroundColor(DiscoveryTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(items) { item in
                        switch item {
                        case .recommendedMission(let mission):
                            Button {
                                onSelectMission(mission)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: mission.isFlexMode
                                          ? (mission.logo ?? "star")
                                          : "calendar.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(mission.isFlexMode
                                                         ? DiscoveryTheme.accentPink
                                                         : DiscoveryTheme.accentBlue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mission.isFlexMode ? mission.displayTitle : mission.title)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(DiscoveryTheme.textPrimary)
                                        if let reason = mission.suggestionReason {
                                            Text(reason)
                                                .font(.caption)
                                                .foregroundColor(DiscoveryTheme.textMuted)
                                        } else if mission.isFlexMode, !mission.tags.isEmpty {
                                            Text(mission.tags.prefix(2).joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundColor(DiscoveryTheme.textMuted)
                                        }
                                    }
                                    Spacer()
                                    if let score = mission.matchScore {
                                        MatchScoreBadge(score: score)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(DiscoveryTheme.textMuted)
                                }
                                .padding(.vertical, 4)
                            }
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .navigationTitle("Recommended For You")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Center Node View

struct CenterNodeView: View {
    let imageUrl: String?
    let username: String
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                DiscoveryTheme.accentBlue.opacity(0.4),
                                DiscoveryTheme.accentTeal.opacity(0.25),
                                DiscoveryTheme.accentBlue.opacity(0.08),
                                DiscoveryTheme.accentBlue.opacity(0.4)
                            ],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(rotationAngle))

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DiscoveryTheme.accentBlue.opacity(0.15),
                                DiscoveryTheme.accentBlue.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulseScale)

                Circle()
                    .fill(DiscoveryTheme.surface)
                    .frame(width: 90, height: 90)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                    .overlay(
                        Group {
                            if let url = imageUrl {
                                AsyncImage(url: URL(string: url)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(DiscoveryTheme.textMuted)
                                }
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(DiscoveryTheme.textMuted)
                            }
                        }
                        .clipShape(Circle())
                    )
                    .overlay(
                        Circle().stroke(DiscoveryTheme.accentBlue.opacity(0.5), lineWidth: 2)
                    )
            }

            Text(username)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(DiscoveryTheme.textPrimary)
        }
        .scaleEffect(appeared ? 1 : 0.5)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                rotationAngle = 8
            }
        }
    }
}

// MARK: - Planet Node View

struct PlanetNodeView: View {
    let planet: PlanetNode
    let isSelected: Bool
    let appearanceDelay: Double
    let onTap: () -> Void

    @State private var floatOffset: CGFloat = 0
    @State private var appeared: Bool = false
    @State private var saturnRotation: Double = 0
    @State private var schedulePulse: CGFloat = 1.0

    private var planetSize: CGFloat { isSelected ? 60 : 52 }
    private var glowSize: CGFloat { isSelected ? 100 : 80 }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Selection haze
                if isSelected {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    planet.accentColor.opacity(0.12),
                                    planet.accentColor.opacity(0.04),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: planetSize / 2,
                                endRadius: glowSize / 2
                            )
                        )
                        .frame(width: glowSize, height: glowSize)
                }

                // Time set: tilted Saturn ring that continuously rotates
                if planet.hasScheduledTime {
                    Ellipse()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    planet.accentColor.opacity(0.6),
                                    planet.accentColor.opacity(0.15),
                                    planet.accentColor.opacity(0.6)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: planetSize + 24, height: 12)
                        .rotationEffect(.degrees(-18))
                        .rotationEffect(.degrees(saturnRotation))
                }

                // Scheduling: frequent, low-opacity pulse ring
                if planet.isScheduling {
                    Circle()
                        .stroke(planet.accentColor.opacity(0.35), lineWidth: 1.5)
                        .frame(width: planetSize + 14, height: planetSize + 14)
                        .scaleEffect(schedulePulse)
                        .opacity(Double(1.6 - schedulePulse))
                }

                // Template: Dashed outline
                if planet.isTemplate {
                    Circle()
                        .stroke(
                            planet.accentColor.opacity(0.4),
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                        .frame(width: planetSize + 10, height: planetSize + 10)
                }

                // Planet body
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    planet.accentColor.opacity(planet.isTemplate ? 0.5 : 0.85),
                                    planet.accentColor.opacity(planet.isTemplate ? 0.3 : 0.6),
                                    planet.accentColor.opacity(planet.isTemplate ? 0.15 : 0.4)
                                ],
                                center: UnitPoint(x: 0.35, y: 0.35),
                                startRadius: 0,
                                endRadius: planetSize / 1.8
                            )
                        )
                        .frame(width: planetSize, height: planetSize)

                    if !planet.isTemplate {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear, Color.clear,
                                        Color.black.opacity(0.15),
                                        Color.black.opacity(0.3)
                                    ],
                                    startPoint: UnitPoint(x: 0.3, y: 0.3),
                                    endPoint: UnitPoint(x: 0.9, y: 0.9)
                                )
                            )
                            .frame(width: planetSize, height: planetSize)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.06),
                                        planet.accentColor.opacity(0.1),
                                        Color.white.opacity(0.04),
                                        planet.accentColor.opacity(0.08),
                                        Color.white.opacity(0.06)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: planetSize, height: planetSize)

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.45),
                                        Color.white.opacity(0.15),
                                        Color.clear
                                    ],
                                    center: UnitPoint(x: 0.3, y: 0.25),
                                    startRadius: 0,
                                    endRadius: planetSize / 3.5
                                )
                            )
                            .frame(width: planetSize, height: planetSize)
                    }

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.clear, Color.clear,
                                    planet.accentColor.opacity(0.3),
                                    planet.accentColor.opacity(0.4)
                                ],
                                startPoint: UnitPoint(x: 0.3, y: 0.3),
                                endPoint: UnitPoint(x: 0.85, y: 0.85)
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: planetSize - 1, height: planetSize - 1)
                }
                .shadow(color: planet.accentColor.opacity(0.2), radius: 8, x: 0, y: 4)

                // Icon overlay (only when the activity type is known)
                if let icon = planet.activityIcon {
                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 20 : 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
        }
        .offset(y: floatOffset)
        .scaleEffect(appeared ? 1 : 0.3)
        .opacity(appeared ? 1 : 0)
        .onTapGesture {
            onTap()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + appearanceDelay) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    appeared = true
                }
                withAnimation(
                    .easeInOut(duration: planet.floatSpeed)
                    .repeatForever(autoreverses: true)
                ) {
                    floatOffset = 6
                }
                if planet.hasScheduledTime {
                    withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                        saturnRotation = 360
                    }
                } else if planet.isScheduling {
                    withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                        schedulePulse = 1.6
                    }
                }
            }
        }
    }
}

// MARK: - Planet Info Label

/// Info card shown for the selected planet. Rendered as a top-level overlay so it
/// always sits above the planets, center node, and the VOYAGE button.
struct PlanetInfoLabel: View {
    let planet: PlanetNode

    var body: some View {
        VStack(spacing: 2) {
            Text(planet.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(DiscoveryTheme.textPrimary)
                .lineLimit(1)

            Text(planet.subtitle)
                .font(.caption2)
                .foregroundColor(DiscoveryTheme.textMuted)

            if let score = planet.matchScore {
                MatchScoreBadge(score: score)
            }

            if planet.isTemplate {
                Text("Tap To Create")
                    .font(.caption2)
                    .foregroundColor(DiscoveryTheme.templateColor)
                    .italic()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DiscoveryTheme.surface)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Connector Line View

struct ConnectorLinesView: View {
    let centerPoint: CGPoint
    let planets: [PlanetNode]
    let planetPositions: [String: CGPoint]

    var body: some View {
        Canvas { context, size in
            for planet in planets {
                guard let planetPos = planetPositions[planet.id] else { continue }
                let dashPattern: [CGFloat] = [4, 6]
                var path = Path()
                path.move(to: centerPoint)
                path.addLine(to: planetPos)
                context.stroke(
                    path,
                    with: .color(planet.accentColor.opacity(0.28)),
                    style: StrokeStyle(lineWidth: 1.2, dash: dashPattern)
                )
            }
        }
    }
}

// MARK: - Loading View

/// Simple placeholder loader: a black star revolving around the center with a
/// "Loading . . ." label. Swapped for a custom animation later.
struct GalaxyLoadingView: View {
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 18) {
            Image("blackStar")
                .resizable()
                .renderingMode(.original)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(rotation))

            Text("Loading . . .")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(DiscoveryTheme.textMuted)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Main Discovery View

struct DiscoveryView: View {
    @Binding var userProfile: Profile
    var isActive: Bool = false

    @StateObject private var viewModel: DiscoveryViewModel
    @StateObject private var missionsVM = MissionsViewModel()
    @State private var imageStars: [ImageStar] = []
    @State private var planets: [PlanetNode] = []
    @State private var selectedPlanetId: String? = nil
    @State private var planetPositions: [String: CGPoint] = [:]
    @State private var selectedMission: Mission? = nil
    @State private var showCreateMission = false
    @State private var createPrefillTitle = ""
    @State private var createPrefillTags: [String] = []
    @State private var showRecommendationsSheet = false
    @State private var showProfile = false
    @State private var showVoyage = false
    @State private var initialLoadDone = false
    @State private var loadVersion = 0

    init(userProfile: Binding<Profile>, isActive: Bool = false) {
        _userProfile = userProfile
        self.isActive = isActive
        _viewModel = StateObject(wrappedValue: DiscoveryViewModel(
            userInterests: userProfile.wrappedValue.interests
        ))
    }

    // Priority ring radii as fraction of half the screen's smaller dimension.
    // Tightened so the cluster sits lower and leaves more room for the banner.
    private let ringRadii: [Int: CGFloat] = [
        0: 0.42,  // hosted — inner ring
        1: 0.58,  // joined — second ring
        2: 0.70,  // recommended — third ring
        3: 0.82   // discoverable/templates — outer ring
    ]

    var body: some View {
        GeometryReader { geometry in
            let centerPoint = CGPoint(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2 + 40
            )
            let halfScreen = min(geometry.size.width, geometry.size.height) / 2

            ZStack {
              // Full-bleed base so the safe-area edges stay filled behind the ScrollView.
              DiscoveryTheme.background
                  .ignoresSafeArea()

              ScrollView {
                ZStack {
                // Tap-to-deselect backdrop
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedPlanetId = nil
                        }
                    }

                // Subtle radial glow
                RadialGradient(
                    colors: [
                        DiscoveryTheme.accentBlue.opacity(0.06),
                        DiscoveryTheme.accentBlue.opacity(0.02),
                        Color.clear
                    ],
                    center: UnitPoint(
                        x: centerPoint.x / geometry.size.width,
                        y: centerPoint.y / geometry.size.height
                    ),
                    startRadius: 50,
                    endRadius: 300
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Squiggle decorations
                SquiggleDecorationView()
                    .allowsHitTesting(false)

                // Image-based star field
                ImageStarFieldView(stars: imageStars, size: geometry.size)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Comet animation
                CometView(
                    screenWidth: geometry.size.width,
                    screenHeight: geometry.size.height
                )
                .allowsHitTesting(false)

                // Connector lines
                ConnectorLinesView(
                    centerPoint: centerPoint,
                    planets: planets,
                    planetPositions: planetPositions
                )
                .allowsHitTesting(false)

                if initialLoadDone {
                    // Planet nodes
                    ForEach(Array(planets.enumerated()), id: \.element.id) { index, planet in
                        let position = calculatePlanetPosition(
                            planet: planet,
                            center: centerPoint,
                            halfScreen: halfScreen
                        )
                        let delay = 0.4 + Double(index) * 0.12

                        PlanetNodeView(
                            planet: planet,
                            isSelected: selectedPlanetId == planet.id,
                            appearanceDelay: delay,
                            onTap: {
                                handlePlanetTap(planet)
                            }
                        )
                        .id("\(loadVersion)-\(planet.id)")
                        .position(position)
                        .onAppear {
                            planetPositions[planet.id] = position
                        }
                    }

                    // Center node (user)
                    CenterNodeView(
                        imageUrl: userProfile.photo,
                        username: userProfile.name
                    )
                    .position(centerPoint)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedPlanetId = nil
                        }
                    }
                } else {
                    // Initial load placeholder
                    GalaxyLoadingView()
                        .position(centerPoint)
                }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
              }
              .scrollIndicators(.hidden)
              .refreshable {
                  planets = []
                  initialLoadDone = false
                  loadVersion += 1
                  await viewModel.reload()
                  generatePlanets(halfScreen: halfScreen, screenSize: geometry.size, center: centerPoint)
                  withAnimation(.easeOut(duration: 0.3)) { initialLoadDone = true }
              }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    // Top bar: bell (left) + profile (right)
                    HStack {
                        RecommendationBellView(
                            showBadge: viewModel.showRecommendationBadge,
                            onTap: { showRecommendationsSheet = true }
                        )
                        Spacer()
                        Button { showProfile = true } label: {
                            ProfileAvatarView(
                                photo: userProfile.photo,
                                size: 34,
                                name: userProfile.name
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                    // Motivational banner
                    MotivationalBannerView()
                }
            }
            .overlay(alignment: .bottom) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showVoyage = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                        Text("VOYAGE")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .tracking(2)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(OrbitTheme.gradientFill)
                    .clipShape(Capsule())
                    .shadow(color: OrbitTheme.purple.opacity(0.4), radius: 12, y: 4)
                }
                .padding(.bottom, 24)
            }
            .overlay {
                // Selected-planet info card — drawn last so it sits above the
                // planets, center node, and VOYAGE button.
                if let selected = planets.first(where: { $0.id == selectedPlanetId }),
                   let pos = planetPositions[selected.id] {
                    PlanetInfoLabel(planet: selected)
                        .fixedSize()
                        .position(x: pos.x, y: pos.y + 56)
                        .transition(.opacity.combined(with: .scale))
                        .allowsHitTesting(false)
                }
            }
            .fullScreenCover(isPresented: $showVoyage) {
                VoyageView()
            }
            .onAppear {
                generateImageStars(in: geometry.size)
                generatePlanets(halfScreen: halfScreen, screenSize: geometry.size, center: centerPoint)
            }
            .task {
                await viewModel.load()
                generatePlanets(halfScreen: halfScreen, screenSize: geometry.size, center: centerPoint)
                withAnimation(.easeOut(duration: 0.3)) {
                    initialLoadDone = true
                }
            }

            .sheet(item: $selectedMission) { mission in
                MissionDetailView(mission: mission, viewModel: missionsVM, onJoined: {
                    selectedMission = nil
                })
            }
            .sheet(isPresented: $showCreateMission) {
                MissionCreateView(
                    viewModel: missionsVM,
                    prefillTitle: createPrefillTitle,
                    prefillTags: createPrefillTags
                )
            }
            .sheet(isPresented: $showRecommendationsSheet) {
                RecommendationsSheet(
                    items: viewModel.items.filter { $0.priority == 2 },
                    onSelectMission: { mission in
                        showRecommendationsSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedMission = mission
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showProfile) {
                ProfileDisplayView(
                    profile: userProfile,
                    onEdit: { showProfile = false },
                    onProfileUpdated: { updated in userProfile = updated }
                )
            }
        }
    }

    // MARK: - Planet Tap Handling

    private func handlePlanetTap(_ planet: PlanetNode) {
        if selectedPlanetId == planet.id {
            // Second tap → open detail or create
            switch planet.type {
            case .mission(let mission):
                selectedMission = mission
            case .template(let template):
                createPrefillTitle = template.title
                createPrefillTags = template.suggestedTags
                showCreateMission = true
            }
        } else {
            withAnimation(.spring(response: 0.3)) {
                selectedPlanetId = planet.id
            }
        }
    }

    // MARK: - Star Generation

    private func generateImageStars(in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let starCount = Int.random(in: 14...18)

        imageStars = (0..<starCount).map { _ in
            let angle = Double.random(in: 0..<(2 * .pi))
            // Some stars drift noticeably faster than others.
            let speed = Double.random(in: 3...10)
            return ImageStar(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 11...19),
                velocity: CGVector(dx: CGFloat(cos(angle) * speed), dy: CGFloat(sin(angle) * speed)),
                twinkleSpeed: Double.random(in: 0.5...2.0),
                phaseOffset: Double.random(in: 0...Double.pi * 2)
            )
        }
    }

    // MARK: - Planet Generation (Priority Rings)

    private let maxPlanets = 7

    /// Minimum pixel distance between any two planet centers to prevent overlap.
    private let minPlanetDistance: CGFloat = 124

    /// Minimum distance from the screen center so planets don't overlap the user profile node.
    private let minCenterDistance: CGFloat = 90

    /// Vertical stretch factor to create an oval layout that uses the taller screen dimension.
    private let verticalStretch: CGFloat = 1.2

    /// Check if a candidate position is valid: no overlap, clear of center profile, and within screen bounds.
    private func isValidPosition(x: CGFloat, y: CGFloat, placed: [(x: CGFloat, y: CGFloat)],
                                  screenSize: CGSize, center: CGPoint) -> Bool {
        let sideMargin: CGFloat = 44    // planet radius (26) + ring (11) + padding
        let topMargin: CGFloat = 150    // top bar + motivational banner + breathing room
        let bottomMargin: CGFloat = 170 // selected info label + VOYAGE button + navbar clearance
        let screenX = center.x + x
        let screenY = center.y + y
        guard screenX >= sideMargin,
              screenX <= screenSize.width - sideMargin,
              screenY >= topMargin,
              screenY <= screenSize.height - bottomMargin else {
            return false
        }
        // Ensure planet doesn't overlap center profile node
        guard hypot(x, y) >= minCenterDistance else {
            return false
        }
        return !placed.contains { hypot(x - $0.x, y - $0.y) < minPlanetDistance }
    }

    private func generatePlanets(halfScreen: CGFloat, screenSize: CGSize, center: CGPoint) {
        let sorted = viewModel.items
            .filter { if case .template = $0 { return false }; return true }
            .sorted { $0.priority < $1.priority }
        let capped = Array(sorted.prefix(maxPlanets))

        let grouped = Dictionary(grouping: capped) { $0.priority }

        var allPlanets: [PlanetNode] = []
        var placed: [(x: CGFloat, y: CGFloat)] = []

        for priority in grouped.keys.sorted() {
            guard let items = grouped[priority], !items.isEmpty else { continue }
            let count = items.count
            let baseAngleStep = (Double.pi * 2) / Double(count)
            let ringOffset = Double(priority) * 0.45
            let ringRadius = (ringRadii[priority] ?? 0.65) * halfScreen

            for (index, item) in items.enumerated() {
                var angle = baseAngleStep * Double(index) + ringOffset
                angle += Double.random(in: -0.15...0.15)
                var radius = ringRadius
                var foundSpot = false

                // Phase 1: nudge angle on the same ring
                for _ in 0..<40 {
                    let x = radius * cos(angle)
                    let y = radius * sin(angle) * verticalStretch
                    if isValidPosition(x: x, y: y, placed: placed, screenSize: screenSize, center: center) {
                        foundSpot = true
                        break
                    }
                    angle += 0.18
                }

                // Phase 2: try shifting radius inward/outward while rotating
                if !foundSpot {
                    let radiusOffsets: [CGFloat] = [-0.08, 0.08, -0.15, 0.15]
                    for rOffset in radiusOffsets {
                        let tryRadius = ringRadius + rOffset * halfScreen
                        for step in 0..<20 {
                            let tryAngle = angle + Double(step) * 0.3
                            let x = tryRadius * cos(tryAngle)
                            let y = tryRadius * sin(tryAngle) * verticalStretch
                            if isValidPosition(x: x, y: y, placed: placed, screenSize: screenSize, center: center) {
                                angle = tryAngle
                                radius = tryRadius
                                foundSpot = true
                                break
                            }
                        }
                        if foundSpot { break }
                    }
                }

                // Phase 3: fine-grained exhaustive sweep as last resort
                if !foundSpot {
                    let minR = minCenterDistance
                    let maxR = 0.98 * halfScreen
                    let rStep: CGFloat = 10
                    let aStep = 0.12
                    outerLoop: for r in stride(from: minR, through: maxR, by: rStep) {
                        for a in stride(from: 0.0, to: Double.pi * 2, by: aStep) {
                            let x = r * cos(a)
                            let y = r * sin(a) * verticalStretch
                            if isValidPosition(x: x, y: y, placed: placed, screenSize: screenSize, center: center) {
                                angle = a
                                radius = r
                                foundSpot = true
                                break outerLoop
                            }
                        }
                    }
                }

                // Only place planet if a valid, non-overlapping position was found
                guard foundSpot else { continue }

                let px = radius * cos(angle)
                let py = radius * sin(angle) * verticalStretch
                placed.append((x: px, y: py))

                let (type, color) = planetTypeAndColor(for: item, index: index)
                let radiusFraction = radius / halfScreen

                allPlanets.append(PlanetNode(
                    id: item.id,
                    type: type,
                    angle: angle,
                    radius: radiusFraction,
                    accentColor: color,
                    floatPhase: Double.random(in: 0...2),
                    floatSpeed: Double.random(in: 2.5...4),
                    priority: priority
                ))
            }
        }

        planets = allPlanets
    }

    private func planetTypeAndColor(for item: DiscoveryItem, index: Int) -> (PlanetType, Color) {
        switch item {
        case .hostedMission(let m), .joinedMission(let m), .recommendedMission(let m), .discoverableMission(let m):
            let colors = m.isFlexMode ? DiscoveryTheme.flexColors : DiscoveryTheme.missionColors
            let color = colors[index % colors.count]
            return (.mission(m), color)
        case .template(let t):
            return (.template(t), DiscoveryTheme.templateColor)
        }
    }

    private func calculatePlanetPosition(planet: PlanetNode, center: CGPoint, halfScreen: CGFloat) -> CGPoint {
        let radius = planet.radius * halfScreen
        let x = center.x + radius * cos(planet.angle)
        let y = center.y + radius * sin(planet.angle) * verticalStretch
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Preview

#Preview {
    DiscoveryView(
        userProfile: .constant(Profile(
            name: "Preview User",
            collegeYear: "junior",
            interests: ["Hiking", "Gaming", "Music"],
            photo: nil,
            trustScore: 4.0,
            email: "test@test.edu"
        ))
    )
}
