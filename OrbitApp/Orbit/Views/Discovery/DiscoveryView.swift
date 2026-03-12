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

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Image Star Model

struct ImageStar: Identifiable {
    let id = UUID()
    let position: CGPoint      // 0-1 normalized
    let size: CGFloat           // 8-16pt
    let isColored: Bool
    let twinkleSpeed: Double
    let phaseOffset: Double
    let floatAmplitude: CGFloat // 1-3pt
    let floatSpeed: Double
}

// MARK: - Planet Node Model

enum PlanetType {
    case mission(Mission)
    case template(TemplateItem)
}

struct PlanetNode: Identifiable {
    let id = UUID()
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
        case .mission(let m): return m.isFlexMode ? (m.activityCategory?.displayName ?? "") : m.displayDate
        case .template(let t):      return t.interest
        }
    }

    var icon: String {
        switch type {
        case .mission(let m):
            return m.isFlexMode ? "antenna.radiowaves.left.and.right" : "calendar.circle.fill"
        case .template:             return "sparkles"
        }
    }

    var isMission: Bool {
        if case .mission(let m) = type { return m.mode == .set }
        return false
    }

    var isFlexMission: Bool {
        if case .mission(let m) = type { return m.isFlexMode }
        return false
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

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(stars) { star in
                    let twinkle = (sin(time * star.twinkleSpeed + star.phaseOffset) + 1) / 2
                    let opacity = 0.3 + twinkle * 0.7
                    let floatY = sin(time * star.floatSpeed + star.phaseOffset) * star.floatAmplitude

                    Image(star.isColored ? "coloredStar" : "blackStar")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: star.size, height: star.size)
                        .opacity(opacity)
                        .offset(y: floatY)
                        .position(
                            x: star.position.x,
                            y: star.position.y
                        )
                }
            }
        }
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
            .rotationEffect(.degrees(-30))
            .opacity(cometOpacity)
            .offset(x: cometOffset, y: cometOffset * 0.5)
            .onAppear {
                scheduleCometStreak()
            }
    }

    private func scheduleCometStreak() {
        let delay = Double.random(in: 15...45)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            fireCometStreak()
        }
    }

    private func fireCometStreak() {
        cometOffset = -200
        cometOpacity = 0
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
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(DiscoveryTheme.textMuted)
            .multilineTextAlignment(.center)
            .id(currentIndex)
            .transition(.opacity)
            .padding(.horizontal, 24)
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
                Image(systemName: "bell.fill")
                    .font(.system(size: 20))
                    .foregroundColor(DiscoveryTheme.textPrimary)
                    .padding(10)

                if showBadge {
                    Circle()
                        .fill(DiscoveryTheme.accentPink)
                        .frame(width: 10, height: 10)
                        .offset(x: -6, y: 8)
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
                                          ? (mission.activityCategory?.icon ?? "star")
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
                                        } else if mission.isFlexMode, let cat = mission.activityCategory {
                                            Text(cat.displayName)
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
    @State private var ringRotation: Double = 0
    @State private var flexPulse: CGFloat = 1.0

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

                // Mission: Saturn-like ring
                if planet.isMission {
                    Ellipse()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    planet.accentColor.opacity(0.5),
                                    planet.accentColor.opacity(0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: planetSize + 22, height: 11)
                        .rotationEffect(.degrees(ringRotation))
                }

                // Flex mission: Radiating pulse rings
                if planet.isFlexMission {
                    Circle()
                        .stroke(planet.accentColor.opacity(0.2), lineWidth: 1)
                        .frame(width: planetSize + 16, height: planetSize + 16)
                        .scaleEffect(flexPulse)
                        .opacity(Double(2.0 - flexPulse))

                    Circle()
                        .stroke(planet.accentColor.opacity(0.12), lineWidth: 1)
                        .frame(width: planetSize + 28, height: planetSize + 28)
                        .scaleEffect(flexPulse)
                        .opacity(Double(2.0 - flexPulse) * 0.5)
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

                // Icon overlay
                Image(systemName: planet.icon)
                    .font(.system(size: isSelected ? 20 : 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
            }

            // Info label on selection
            if isSelected {
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
                        Text("tap to create")
                            .font(.caption2)
                            .foregroundColor(DiscoveryTheme.templateColor)
                            .italic()
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DiscoveryTheme.surface)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                .transition(.opacity.combined(with: .scale))
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
                if planet.isMission {
                    withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                        ringRotation = 10
                    }
                } else if planet.isFlexMission {
                    withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                        flexPulse = 1.5
                    }
                }
            }
        }
    }
}

// MARK: - Connector Line View

struct ConnectorLinesView: View {
    let centerPoint: CGPoint
    let planets: [PlanetNode]
    let planetPositions: [UUID: CGPoint]

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
                    with: .color(planet.accentColor.opacity(0.25)),
                    style: StrokeStyle(lineWidth: 1, dash: dashPattern)
                )
            }
        }
    }
}

// MARK: - Legend View

struct DiscoveryLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            LegendItem(color: DiscoveryTheme.accentBlue, label: "Set", icon: "calendar.circle.fill")
            LegendItem(color: DiscoveryTheme.accentPink, label: "Flex", icon: "antenna.radiowaves.left.and.right")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(DiscoveryTheme.surface.opacity(0.9))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(DiscoveryTheme.textPrimary)
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
    @State private var selectedPlanetId: UUID? = nil
    @State private var planetPositions: [UUID: CGPoint] = [:]
    @State private var selectedMission: Mission? = nil
    @State private var discOpenPodId: String? = nil
    @State private var discOpenPodTitle: String = ""
    @State private var discOpenPodMode: MissionMode = .set
    @State private var showDiscPod = false
    @State private var showCreateMission = false
    @State private var createPrefillTitle = ""
    @State private var createPrefillTags: [String] = []
    @State private var showRecommendationsSheet = false
    @State private var showProfile = false
    @State private var showVoyage = false

    init(userProfile: Binding<Profile>, isActive: Bool = false) {
        _userProfile = userProfile
        self.isActive = isActive
        _viewModel = StateObject(wrappedValue: DiscoveryViewModel(
            userInterests: userProfile.wrappedValue.interests
        ))
    }

    // Priority ring radii as fraction of half the screen's smaller dimension
    private let ringRadii: [Int: CGFloat] = [
        0: 0.55,  // hosted — inner ring
        1: 0.72,  // joined — second ring
        2: 0.85,  // recommended — third ring
        3: 0.96   // discoverable/templates — outer ring
    ]

    var body: some View {
        GeometryReader { geometry in
            let centerPoint = CGPoint(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2 - 40
            )
            let halfScreen = min(geometry.size.width, geometry.size.height) / 2

            ZStack {
                // Background
                DiscoveryTheme.background
                    .ignoresSafeArea()
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
                ImageStarFieldView(stars: imageStars)
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
            }
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    // Top bar: bell (left) + legend (center) + profile (right)
                    HStack {
                        RecommendationBellView(
                            showBadge: viewModel.showRecommendationBadge,
                            onTap: { showRecommendationsSheet = true }
                        )
                        Spacer()
                        DiscoveryLegend()
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
                    .padding(.top, 8)

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
            .fullScreenCover(isPresented: $showVoyage) {
                VoyageView()
            }
            .onAppear {
                generateImageStars(in: geometry.size)
                generatePlanets(halfScreen: halfScreen, screenSize: geometry.size, center: centerPoint)
            }
            .task {
                await viewModel.load()
                viewModel.startBellTimer()
                generatePlanets(halfScreen: halfScreen, screenSize: geometry.size, center: centerPoint)
            }
            .onChange(of: viewModel.items) {
                generatePlanets(halfScreen: halfScreen, screenSize: geometry.size, center: centerPoint)
            }
            .onChange(of: isActive) { _, active in
                if active {
                    Task {
                        await viewModel.reload()
                        generatePlanets(halfScreen: halfScreen, screenSize: geometry.size, center: centerPoint)
                    }
                }
            }
            .sheet(item: $selectedMission, onDismiss: {
                if discOpenPodId != nil {
                    showDiscPod = true
                }
            }) { mission in
                MissionDetailView(mission: mission, onJoined: {
                    selectedMission = nil
                }, onOpenPod: { podId in
                    discOpenPodId = podId
                    discOpenPodTitle = mission.isFlexMode ? mission.displayTitle : mission.title
                    discOpenPodMode = mission.mode
                    selectedMission = nil
                })
            }
            .sheet(isPresented: $showDiscPod, onDismiss: {
                discOpenPodId = nil
            }) {
                if let podId = discOpenPodId {
                    PodView(podId: podId, title: discOpenPodTitle, missionMode: discOpenPodMode)
                }
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
        let starCount = 16
        let minDistance: CGFloat = 50
        // Keep stars below the top bar + motivational banner (~100pt)
        let topInset: CGFloat = 100
        var positions: [CGPoint] = []

        for _ in 0..<starCount {
            var candidate = CGPoint(
                x: CGFloat.random(in: 30...(size.width - 30)),
                y: CGFloat.random(in: topInset...(size.height - 30))
            )
            // Try to find a position far enough from existing stars
            for _ in 0..<20 {
                let tooClose = positions.contains { existing in
                    hypot(existing.x - candidate.x, existing.y - candidate.y) < minDistance
                }
                if !tooClose { break }
                candidate = CGPoint(
                    x: CGFloat.random(in: 30...(size.width - 30)),
                    y: CGFloat.random(in: topInset...(size.height - 30))
                )
            }
            positions.append(candidate)
        }

        imageStars = positions.map { pos in
            ImageStar(
                position: pos,
                size: CGFloat.random(in: 8...16),
                isColored: false,
                twinkleSpeed: Double.random(in: 0.5...2.0),
                phaseOffset: Double.random(in: 0...Double.pi * 2),
                floatAmplitude: CGFloat.random(in: 1...3),
                floatSpeed: Double.random(in: 0.3...0.8)
            )
        }
    }

    // MARK: - Planet Generation (Priority Rings)

    private let maxPlanets = 7

    /// Minimum pixel distance between any two planet centers to prevent overlap.
    private let minPlanetDistance: CGFloat = 150

    /// Minimum distance from the screen center so planets don't overlap the user profile node.
    private let minCenterDistance: CGFloat = 100

    /// Vertical stretch factor to create an oval layout that uses the taller screen dimension.
    private let verticalStretch: CGFloat = 1.4

    /// Check if a candidate position is valid: no overlap, clear of center profile, and within screen bounds.
    private func isValidPosition(x: CGFloat, y: CGFloat, placed: [(x: CGFloat, y: CGFloat)],
                                  screenSize: CGSize, center: CGPoint) -> Bool {
        // Planet radius (half of 52pt size) plus padding
        let margin: CGFloat = 36
        let screenX = center.x + x
        let screenY = center.y + y
        guard screenX >= margin,
              screenX <= screenSize.width - margin,
              screenY >= margin,
              screenY <= screenSize.height - margin else {
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

                // Phase 3: exhaustive sweep as last resort
                if !foundSpot {
                    let minR = minCenterDistance
                    let maxR = 0.98 * halfScreen
                    let rStep: CGFloat = 20
                    let aStep = 0.25
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

                let px = radius * cos(angle)
                let py = radius * sin(angle) * verticalStretch
                placed.append((x: px, y: py))

                let (type, color) = planetTypeAndColor(for: item, index: index)
                let radiusFraction = radius / halfScreen

                allPlanets.append(PlanetNode(
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
