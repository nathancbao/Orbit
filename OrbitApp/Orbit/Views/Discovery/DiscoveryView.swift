//
//  DiscoveryView.swift
//  Orbit
//
//  Galaxy-themed discovery view showing events and missions as planets
//

import SwiftUI

// MARK: - Color Palette

enum DiscoveryTheme {
    static let background = Color(hex: "020408")
    static let surface = Color(hex: "0d1117")
    static let accentBlue = Color(hex: "3B82F6")
    static let accentTeal = Color(hex: "2DD4BF")
    static let accentLavender = Color(hex: "A78BFA")
    static let accentAmber = Color(hex: "F59E0B")
    static let accentPink = Color(hex: "EC4899")
    static let accentGreen = Color(hex: "10B981")
    static let textPrimary = Color(hex: "E2E8F0")
    static let textMuted = Color(hex: "64748B")
    static let glow = Color(hex: "3B82F6").opacity(0.15)

    // Event planets: cooler tones (blue, teal, green)
    static let eventColors: [Color] = [accentBlue, accentTeal, accentGreen]

    // Mission planets: warmer tones (amber, pink, lavender)
    static let missionColors: [Color] = [accentAmber, accentPink, accentLavender]
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

// MARK: - Star Model

struct Star: Identifiable {
    let id = UUID()
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
    let twinkleSpeed: Double
    let phaseOffset: Double
}

// MARK: - Planet Node Model

enum PlanetType {
    case mission(Mission)
    case signal(Signal)
}

struct PlanetNode: Identifiable {
    let id = UUID()
    let type: PlanetType
    let angle: Double
    let radius: CGFloat
    let accentColor: Color
    let floatPhase: Double
    let floatSpeed: Double

    var title: String {
        switch type {
        case .mission(let mission): return mission.title
        case .signal(let signal): return signal.displayTitle
        }
    }

    var subtitle: String {
        switch type {
        case .mission(let mission): return mission.displayDate
        case .signal(let signal): return signal.activityCategory.displayName
        }
    }

    var icon: String {
        switch type {
        case .mission: return "calendar.circle.fill"
        case .signal(let signal): return signal.activityCategory.icon
        }
    }

    var isMission: Bool {
        if case .mission = type { return true }
        return false
    }
}

// MARK: - Star Field View

struct StarFieldView: View {
    let stars: [Star]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                for star in stars {
                    let twinkle = (sin(time * star.twinkleSpeed + star.phaseOffset) + 1) / 2
                    let currentOpacity = star.opacity * (0.3 + twinkle * 0.7)

                    let rect = CGRect(
                        x: star.position.x * size.width - star.size / 2,
                        y: star.position.y * size.height - star.size / 2,
                        width: star.size,
                        height: star.size
                    )

                    context.opacity = currentOpacity
                    context.fill(Circle().path(in: rect), with: .color(.white))
                }
            }
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
                // Outer rotating orbit halo
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                DiscoveryTheme.accentBlue.opacity(0.5),
                                DiscoveryTheme.accentTeal.opacity(0.3),
                                DiscoveryTheme.accentBlue.opacity(0.1),
                                DiscoveryTheme.accentBlue.opacity(0.5)
                            ],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(rotationAngle))

                // Pulsing glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DiscoveryTheme.accentBlue.opacity(0.4),
                                DiscoveryTheme.accentBlue.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulseScale)

                // Profile image
                Circle()
                    .fill(DiscoveryTheme.surface)
                    .frame(width: 90, height: 90)
                    .overlay(
                        Group {
                            if let url = imageUrl {
                                AsyncImage(url: URL(string: url)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
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
                        Circle()
                            .stroke(DiscoveryTheme.accentBlue.opacity(0.6), lineWidth: 2)
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

            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotationAngle = 360
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

    private var planetSize: CGFloat { isSelected ? 60 : 52 }
    private var glowSize: CGFloat { isSelected ? 100 : 80 }

    // Darker, more muted base color for realistic planet surface
    private var baseColor: Color {
        planet.accentColor.opacity(0.7)
    }

    // Even darker shadow color
    private var shadowColor: Color {
        Color.black.opacity(0.6)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Subtle atmospheric haze (much more subtle than before)
                if isSelected {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    planet.accentColor.opacity(0.15),
                                    planet.accentColor.opacity(0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: planetSize / 2,
                                endRadius: glowSize / 2
                            )
                        )
                        .frame(width: glowSize, height: glowSize)
                }

                // Ring for missions (Saturn-like) - more subtle
                if planet.isMission {
                    Ellipse()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    planet.accentColor.opacity(0.4),
                                    planet.accentColor.opacity(0.15)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: planetSize + 20, height: 10)
                        .rotationEffect(.degrees(ringRotation))
                }

                // Planet base with realistic lighting
                ZStack {
                    // Main planet body - darker base
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    planet.accentColor.opacity(0.5),
                                    planet.accentColor.opacity(0.35),
                                    planet.accentColor.opacity(0.2)
                                ],
                                center: UnitPoint(x: 0.35, y: 0.35),
                                startRadius: 0,
                                endRadius: planetSize / 1.8
                            )
                        )
                        .frame(width: planetSize, height: planetSize)

                    // Dark side shadow (terminator line effect)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.clear,
                                    Color.black.opacity(0.3),
                                    Color.black.opacity(0.5)
                                ],
                                startPoint: UnitPoint(x: 0.3, y: 0.3),
                                endPoint: UnitPoint(x: 0.9, y: 0.9)
                            )
                        )
                        .frame(width: planetSize, height: planetSize)

                    // Limb darkening effect (edges darker)
                    Circle()
                        .stroke(
                            RadialGradient(
                                colors: [
                                    Color.clear,
                                    Color.black.opacity(0.25)
                                ],
                                center: .center,
                                startRadius: planetSize / 3,
                                endRadius: planetSize / 2
                            ),
                            lineWidth: planetSize / 4
                        )
                        .frame(width: planetSize, height: planetSize)

                    // Surface band/texture (horizontal banding like gas giants)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.03),
                                    planet.accentColor.opacity(0.08),
                                    Color.white.opacity(0.02),
                                    planet.accentColor.opacity(0.06),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: planetSize, height: planetSize)

                    // Specular highlight (subtle light reflection)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                center: UnitPoint(x: 0.3, y: 0.25),
                                startRadius: 0,
                                endRadius: planetSize / 4
                            )
                        )
                        .frame(width: planetSize, height: planetSize)

                    // Subtle rim light (atmosphere backlight)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.clear,
                                    planet.accentColor.opacity(0.2),
                                    planet.accentColor.opacity(0.3)
                                ],
                                startPoint: UnitPoint(x: 0.3, y: 0.3),
                                endPoint: UnitPoint(x: 0.85, y: 0.85)
                            ),
                            lineWidth: 1
                        )
                        .frame(width: planetSize - 1, height: planetSize - 1)
                }

                // Icon overlay - slightly more transparent
                Image(systemName: planet.icon)
                    .font(.system(size: isSelected ? 20 : 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
            }

            // Info label (visible on selection)
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
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DiscoveryTheme.surface.opacity(0.9))
                .cornerRadius(8)
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
                // Slow ring rotation for missions
                if planet.isMission {
                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                        ringRotation = 360
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
                    with: .color(planet.accentColor.opacity(0.15)),
                    style: StrokeStyle(lineWidth: 1, dash: dashPattern)
                )
            }
        }
    }
}

// MARK: - Voyage Button

struct VoyageButton: View {
    @State private var glowPulse: CGFloat = 1.0

    var body: some View {
        Button(action: {
            // No functionality yet
        }) {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .rotationEffect(.degrees(-45))

                Text("Voyage")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    Capsule()
                        .fill(DiscoveryTheme.accentBlue.opacity(0.3))
                        .blur(radius: 8)
                        .scaleEffect(glowPulse)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DiscoveryTheme.accentBlue,
                                    DiscoveryTheme.accentTeal.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    DiscoveryTheme.accentTeal.opacity(0.8),
                                    DiscoveryTheme.accentBlue.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
        }
        .buttonStyle(VoyageButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPulse = 1.15
            }
        }
    }
}

struct VoyageButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Bottom Navigation Bar

struct DiscoveryNavBar: View {
    @Binding var selectedTab: DiscoveryNavTab

    enum DiscoveryNavTab: String, CaseIterable {
        case home = "house.fill"
        case discovery = "sparkles"
        case notifications = "bell.fill"
        case profile = "person.fill"

        var label: String {
            switch self {
            case .home: return "Home"
            case .discovery: return "Discovery"
            case .notifications: return "Notifications"
            case .profile: return "Profile"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DiscoveryNavTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            if selectedTab == tab {
                                Circle()
                                    .fill(DiscoveryTheme.accentBlue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                            }

                            Image(systemName: tab.rawValue)
                                .font(.system(size: 20))
                                .foregroundColor(
                                    selectedTab == tab
                                        ? DiscoveryTheme.accentBlue
                                        : DiscoveryTheme.textMuted
                                )
                        }

                        Text(tab.label)
                            .font(.caption2)
                            .foregroundColor(
                                selectedTab == tab
                                    ? DiscoveryTheme.accentBlue
                                    : DiscoveryTheme.textMuted
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.bottom, 20)
        .background(
            ZStack {
                DiscoveryTheme.surface.opacity(0.85)

                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DiscoveryTheme.accentBlue.opacity(0.3),
                                    DiscoveryTheme.accentTeal.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 1)
                    Spacer()
                }
            }
            .background(.ultraThinMaterial)
        )
    }
}

// MARK: - Legend View

struct DiscoveryLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            LegendItem(color: DiscoveryTheme.accentTeal, label: "Missions", icon: "calendar.circle.fill")
            LegendItem(color: DiscoveryTheme.accentAmber, label: "Signals", icon: "antenna.radiowaves.left.and.right")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(DiscoveryTheme.surface.opacity(0.7))
        .cornerRadius(12)
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
                .foregroundColor(DiscoveryTheme.textMuted)
        }
    }
}

// MARK: - Main Discovery View

struct DiscoveryView: View {
    let userProfile: Profile

    @State private var stars: [Star] = []
    @State private var planets: [PlanetNode] = []
    @State private var selectedPlanetId: UUID? = nil
    @State private var planetPositions: [UUID: CGPoint] = [:]
    @State private var selectedMission: Mission? = nil
    @State private var selectedSignal: Signal? = nil

    private let minRadius: CGFloat = 110
    private let maxRadius: CGFloat = 170

    var body: some View {
        GeometryReader { geometry in
            let centerPoint = CGPoint(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2 - 60
            )

            ZStack {
                // Background
                DiscoveryTheme.background
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Tap on background deselects any selected planet
                        withAnimation(.spring(response: 0.3)) {
                            selectedPlanetId = nil
                        }
                    }

                // Radial glow from center
                RadialGradient(
                    colors: [
                        DiscoveryTheme.accentBlue.opacity(0.08),
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

                // Star field
                StarFieldView(stars: stars)
                    .ignoresSafeArea()
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
                        center: centerPoint
                    )
                    let delay = 0.4 + Double(index) * 0.12

                    PlanetNodeView(
                        planet: planet,
                        isSelected: selectedPlanetId == planet.id,
                        appearanceDelay: delay,
                        onTap: {
                            if selectedPlanetId == planet.id {
                                // Second tap on selected planet → open detail
                                switch planet.type {
                                case .mission(let mission):
                                    selectedMission = mission
                                case .signal(let signal):
                                    selectedSignal = signal
                                }
                            } else {
                                // First tap → select planet
                                withAnimation(.spring(response: 0.3)) {
                                    selectedPlanetId = planet.id
                                }
                            }
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
                // Legend at top
                DiscoveryLegend()
                    .padding(.top, 60)
            }
            .overlay(alignment: .bottom) {
                // Voyage button
                VoyageButton()
                    .padding(.bottom, 32)
            }
            .onAppear {
                generateStars(in: geometry.size)
                generatePlanets()
            }
            .sheet(item: $selectedMission) { mission in
                MissionDetailView(mission: mission, onJoined: {})
            }
            .sheet(item: $selectedSignal) { signal in
                SignalDetailView(signal: signal)
            }
        }
    }

    // MARK: - Helper Functions

    private func generateStars(in size: CGSize) {
        stars = (0..<120).map { _ in
            Star(
                position: CGPoint(
                    x: CGFloat.random(in: 0...1),
                    y: CGFloat.random(in: 0...1)
                ),
                size: CGFloat.random(in: 1...2.5),
                opacity: Double.random(in: 0.3...0.8),
                twinkleSpeed: Double.random(in: 0.5...2),
                phaseOffset: Double.random(in: 0...Double.pi * 2)
            )
        }
    }

    private func generatePlanets() {
        var allPlanets: [PlanetNode] = []
        var usedAngles: [Double] = []
        let minAngleSeparation = 0.6

        // Add missions (fixed-date events)
        for (index, mission) in MockData.mockMissions.enumerated() {
            let angle = findAvailableAngle(usedAngles: &usedAngles, minSeparation: minAngleSeparation)
            let color = DiscoveryTheme.eventColors[index % DiscoveryTheme.eventColors.count]

            allPlanets.append(PlanetNode(
                type: .mission(mission),
                angle: angle,
                radius: CGFloat.random(in: minRadius...maxRadius),
                accentColor: color,
                floatPhase: Double.random(in: 0...2),
                floatSpeed: Double.random(in: 2.5...4)
            ))
        }

        // Add signals (spontaneous activity requests)
        for (index, signal) in MockData.mockSignals.enumerated() {
            let angle = findAvailableAngle(usedAngles: &usedAngles, minSeparation: minAngleSeparation)
            let color = DiscoveryTheme.missionColors[index % DiscoveryTheme.missionColors.count]

            allPlanets.append(PlanetNode(
                type: .signal(signal),
                angle: angle,
                radius: CGFloat.random(in: minRadius...maxRadius),
                accentColor: color,
                floatPhase: Double.random(in: 0...2),
                floatSpeed: Double.random(in: 2.5...4)
            ))
        }

        planets = allPlanets
    }

    private func findAvailableAngle(usedAngles: inout [Double], minSeparation: Double) -> Double {
        var angle: Double
        var attempts = 0

        repeat {
            angle = Double.random(in: 0...(Double.pi * 2))
            attempts += 1
        } while attempts < 50 && usedAngles.contains(where: {
            let diff = abs($0 - angle)
            return min(diff, Double.pi * 2 - diff) < minSeparation
        })

        usedAngles.append(angle)
        return angle
    }

    private func calculatePlanetPosition(planet: PlanetNode, center: CGPoint) -> CGPoint {
        let x = center.x + planet.radius * cos(planet.angle)
        let y = center.y + planet.radius * sin(planet.angle)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Preview

#Preview {
    DiscoveryView(
        userProfile: Profile(
            name: "Preview User",
            collegeYear: "junior",
            interests: ["coding", "music"],
            photo: nil,
            trustScore: 4.0,
            email: "test@test.edu"
        )
    )
}
