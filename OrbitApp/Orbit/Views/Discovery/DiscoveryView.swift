//
//  DiscoveryView.swift
//  Orbit
//
//  Galaxy-themed discovery view with solar system layout
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
    static let textPrimary = Color(hex: "E2E8F0")
    static let textMuted = Color(hex: "64748B")
    static let glow = Color(hex: "3B82F6").opacity(0.15)

    static let nodeAccents: [Color] = [accentTeal, accentLavender, accentAmber, accentBlue]
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

// MARK: - Cluster Node Model

struct ClusterNode: Identifiable {
    let id = UUID()
    let name: String
    let imageUrl: String?
    let angle: Double      // radians
    let radius: CGFloat    // distance from center
    let accentColor: Color
    let floatPhase: Double // phase offset for floating animation
    let floatSpeed: Double // speed of floating animation
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

            // Pulsing animation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }

            // Rotation animation
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - Cluster Node View

struct ClusterNodeView: View {
    let node: ClusterNode
    let isSelected: Bool
    let appearanceDelay: Double
    let onTap: () -> Void

    @State private var floatOffset: CGFloat = 0
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Glow background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                node.accentColor.opacity(isSelected ? 0.5 : 0.25),
                                node.accentColor.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: isSelected ? 50 : 40
                        )
                    )
                    .frame(width: isSelected ? 90 : 70, height: isSelected ? 90 : 70)

                // Avatar
                Circle()
                    .fill(DiscoveryTheme.surface)
                    .frame(width: isSelected ? 56 : 48, height: isSelected ? 56 : 48)
                    .overlay(
                        Group {
                            if let url = node.imageUrl {
                                AsyncImage(url: URL(string: url)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(DiscoveryTheme.textMuted)
                                }
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(DiscoveryTheme.textMuted)
                            }
                        }
                        .clipShape(Circle())
                    )
                    .overlay(
                        Circle()
                            .stroke(node.accentColor.opacity(0.6), lineWidth: 1.5)
                    )
            }

            // Name label (visible on selection)
            if isSelected {
                Text(node.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(DiscoveryTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DiscoveryTheme.surface.opacity(0.8))
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
            // Staggered appearance animation
            DispatchQueue.main.asyncAfter(deadline: .now() + appearanceDelay) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    appeared = true
                }
                // Start floating animation after appearance
                withAnimation(
                    .easeInOut(duration: node.floatSpeed)
                    .repeatForever(autoreverses: true)
                ) {
                    floatOffset = 6
                }
            }
        }
    }
}

// MARK: - Connector Line View

struct ConnectorLinesView: View {
    let centerPoint: CGPoint
    let nodes: [ClusterNode]
    let nodePositions: [UUID: CGPoint]

    var body: some View {
        Canvas { context, size in
            for node in nodes {
                guard let nodePos = nodePositions[node.id] else { continue }

                let dashPattern: [CGFloat] = [4, 6]
                var path = Path()
                path.move(to: centerPoint)
                path.addLine(to: nodePos)

                context.stroke(
                    path,
                    with: .color(DiscoveryTheme.textMuted.opacity(0.2)),
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
                    // Glow layer
                    Capsule()
                        .fill(DiscoveryTheme.accentBlue.opacity(0.3))
                        .blur(radius: 8)
                        .scaleEffect(glowPulse)

                    // Main button
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

                    // Border
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
                // Frosted glass effect
                DiscoveryTheme.surface.opacity(0.85)

                // Top border glow
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

// MARK: - Main Discovery View

struct DiscoveryView: View {
    let userProfile: Profile

    @State private var stars: [Star] = []
    @State private var clusterNodes: [ClusterNode] = []
    @State private var selectedNodeId: UUID? = nil
    @State private var nodePositions: [UUID: CGPoint] = [:]
    @State private var selectedNavTab: DiscoveryNavBar.DiscoveryNavTab = .discovery

    // Geometry
    private let centerNodeSize: CGFloat = 90
    private let minRadius: CGFloat = 100
    private let maxRadius: CGFloat = 160

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

                // Star field
                StarFieldView(stars: stars)
                    .ignoresSafeArea()

                // Connector lines
                ConnectorLinesView(
                    centerPoint: centerPoint,
                    nodes: clusterNodes,
                    nodePositions: nodePositions
                )

                // Cluster nodes
                ForEach(Array(clusterNodes.enumerated()), id: \.element.id) { index, node in
                    let position = calculateNodePosition(
                        node: node,
                        center: centerPoint
                    )
                    let delay = 0.4 + Double(index) * 0.1

                    ClusterNodeView(
                        node: node,
                        isSelected: selectedNodeId == node.id,
                        appearanceDelay: delay,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedNodeId = selectedNodeId == node.id ? nil : node.id
                            }
                        }
                    )
                    .position(position)
                    .onAppear {
                        // Store position for connector lines
                        nodePositions[node.id] = position
                    }
                }

                // Center node
                CenterNodeView(
                    imageUrl: userProfile.photo,
                    username: userProfile.name
                )
                .position(centerPoint)

                // Voyage button and nav bar
                VStack {
                    Spacer()

                    VoyageButton()
                        .padding(.bottom, 16)

                    DiscoveryNavBar(selectedTab: $selectedNavTab)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .onAppear {
                generateStars(in: geometry.size)
                generateClusterNodes()
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

    private func generateClusterNodes() {
        let placeholderNames = [
            "Alex", "Jordan", "Taylor", "Morgan", "Casey",
            "Riley", "Quinn", "Avery", "Skyler", "Dakota"
        ]

        let nodeCount = Int.random(in: 6...10)
        var usedAngles: [Double] = []
        let minAngleSeparation = 0.5 // radians (~28 degrees)

        clusterNodes = (0..<nodeCount).map { index in
            // Generate angle with some randomness but avoid overlap
            var angle: Double
            var attempts = 0
            let maxAttempts = 50

            repeat {
                angle = Double.random(in: 0...(Double.pi * 2))
                attempts += 1
            } while attempts < maxAttempts && usedAngles.contains(where: {
                let diff = abs($0 - angle)
                // Check both direct distance and wrap-around distance
                return min(diff, Double.pi * 2 - diff) < minAngleSeparation
            })
            usedAngles.append(angle)

            let radius = CGFloat.random(in: minRadius...maxRadius)
            let accentColor = DiscoveryTheme.nodeAccents[index % DiscoveryTheme.nodeAccents.count]

            return ClusterNode(
                name: placeholderNames[index % placeholderNames.count],
                imageUrl: nil, // Using placeholder for now
                angle: angle,
                radius: radius,
                accentColor: accentColor,
                floatPhase: Double.random(in: 0...2),
                floatSpeed: Double.random(in: 2.5...4)
            )
        }
    }

    private func calculateNodePosition(node: ClusterNode, center: CGPoint) -> CGPoint {
        let x = center.x + node.radius * cos(node.angle)
        let y = center.y + node.radius * sin(node.angle)
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
