//
//  VoyageView.swift
//  Orbit
//
//  Fullscreen infinite 2D exploration — panning through tile-based clusters
//  of missions and signals against a dense parallax star field.
//  Tap a solar system to zoom in and browse its events.
//

import SwiftUI

// MARK: - Voyage Star

private struct VoyageStar: Identifiable {
    let id: Int
    let x: CGFloat          // 0...1 fraction of screen width
    let y: CGFloat          // 0...1 fraction of screen height
    let size: CGFloat       // 1...3 pt
    let baseOpacity: Double // 0.2...0.8
    let twinkleSpeed: Double
    let phaseOffset: Double
    let parallaxFactor: CGFloat // 0.02...0.15 — how much this star drifts with pan
}

// MARK: - Main Voyage View

struct VoyageView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = VoyageViewModel()

    // Animation state
    @State private var entryScale: CGFloat = 3.0
    @State private var entryOpacity: Double = 0
    @State private var isExiting = false
    @State private var exitScale: CGFloat = 1.0
    @State private var exitOpacity: Double = 1.0

    // Pan gesture state
    @State private var dragOffset: CGSize = .zero
    @State private var lastDragValue: CGSize = .zero

    // Stars
    @State private var stars: [VoyageStar] = []
    @State private var screenSize: CGSize = .zero

    // Detail sheet
    @State private var selectedItem: VoyageItem? = nil

    // Zoom into a cluster
    @State private var zoomedTile: VoyageTile? = nil

    // Pinch-to-zoom
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0

    /// Compact solar system diameter shown in the tile grid.
    private let compactDiameter: CGFloat = 160

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Pure black background
                Color.black.ignoresSafeArea()

                // Parallax star field
                starFieldLayer(size: geo.size)

                // Tile content layer — moves with pan, scales with pinch
                tileContentLayer(size: geo.size)
                    .scaleEffect(zoomScale)

                // Home direction indicator
                if viewModel.distanceFromHome > 2 && zoomedTile == nil {
                    VoyageHomeIndicator(angle: viewModel.homeAngle)
                }

                // Top hint
                if zoomedTile == nil {
                    VStack {
                        Text("Tap on solar systems to explore more activities!")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .tracking(0.4)
                            .foregroundStyle(OrbitTheme.gradient)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [OrbitTheme.pink.opacity(0.4), OrbitTheme.purple.opacity(0.3), OrbitTheme.blue.opacity(0.4)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            )
                            .padding(.top, 60)
                        Spacer()
                    }
                }

                // End Voyage button
                if zoomedTile == nil {
                    endVoyageButton
                }

                // Loading — rocket launch animation
                if viewModel.isLoading {
                    VoyageRocketLoading()
                }

                // Zoomed cluster overlay
                if let tile = zoomedTile {
                    zoomedOverlay(tile: tile, screenSize: geo.size)
                }
            }
            .scaleEffect(isExiting ? exitScale : entryScale)
            .opacity(isExiting ? exitOpacity : entryOpacity)
            .onAppear {
                screenSize = geo.size
                generateStars(count: 200, size: geo.size)
                withAnimation(.easeOut(duration: 0.6)) {
                    entryScale = 1.0
                    entryOpacity = 1.0
                }
            }
            .gesture(panGesture)
            .simultaneousGesture(pinchGesture)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .task {
            await viewModel.startVoyage()
        }
        .sheet(item: $selectedItem) { item in
            VoyageItemDetailSheet(item: item)
        }
    }

    // MARK: - Star Field

    private func starFieldLayer(size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let velocity = viewModel.dragVelocity
                let speed = hypot(velocity.width, velocity.height)
                let warpFactor = min(speed / 800, 1.0) // 0...1
                let w = canvasSize.width
                let h = canvasSize.height

                // ── Background stars ──
                for star in stars {
                    let px = viewModel.voyagePosition.x * star.parallaxFactor
                    let py = viewModel.voyagePosition.y * star.parallaxFactor

                    var sx = (star.x * w + px).truncatingRemainder(dividingBy: w)
                    var sy = (star.y * h + py).truncatingRemainder(dividingBy: h)
                    if sx < 0 { sx += w }
                    if sy < 0 { sy += h }

                    let twinkle = (sin(time * star.twinkleSpeed + star.phaseOffset) + 1) / 2
                    let opacity = star.baseOpacity + twinkle * (1.0 - star.baseOpacity)

                    if warpFactor > 0.1 {
                        let streakLength = star.size + warpFactor * 12
                        let angle = atan2(-velocity.height, -velocity.width)
                        let dx = cos(angle) * streakLength / 2
                        let dy = sin(angle) * streakLength / 2

                        var path = Path()
                        path.move(to: CGPoint(x: sx - dx, y: sy - dy))
                        path.addLine(to: CGPoint(x: sx + dx, y: sy + dy))
                        context.stroke(path, with: .color(.white.opacity(opacity * 0.8)),
                                       lineWidth: star.size * 0.6)
                    } else {
                        let rect = CGRect(x: sx - star.size / 2, y: sy - star.size / 2,
                                          width: star.size, height: star.size)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                    }
                }

                // ── Shooting stars (3 staggered slots) ──
                let shootingIntervals: [Double] = [45.0, 65.0, 90.0]
                for (si, interval) in shootingIntervals.enumerated() {
                    let idx = Int(time / interval)
                    let t = time - Double(idx) * interval
                    let duration = 1.2
                    guard t < duration else { continue }

                    // Deterministic start, angle, length from slot + index
                    var seed = UInt64(idx &* 2654435761 &+ si &* 73856093)
                    seed = seed ^ (seed >> 17)
                    let startX = CGFloat(seed % 1000) / 1000.0 * w
                    seed = seed &* 6364136223846793005 &+ 1
                    let startY = CGFloat(seed % 1000) / 1000.0 * h
                    seed = seed &* 6364136223846793005 &+ 1
                    let angle = Double(seed % 628) / 100.0 // ~0...6.28

                    let progress = t / duration
                    let tailLen: CGFloat = 60 + CGFloat(seed % 40)
                    let headX = startX + CGFloat(cos(angle)) * tailLen * 4 * CGFloat(progress)
                    let headY = startY + CGFloat(sin(angle)) * tailLen * 4 * CGFloat(progress)
                    let tailX = headX - CGFloat(cos(angle)) * tailLen
                    let tailY = headY - CGFloat(sin(angle)) * tailLen

                    let fade = 1.0 - progress  // bright at start, fades out

                    var streak = Path()
                    streak.move(to: CGPoint(x: tailX, y: tailY))
                    streak.addLine(to: CGPoint(x: headX, y: headY))
                    context.stroke(streak, with: .color(.white.opacity(fade * 0.8)), lineWidth: 1.5)

                    // Bright head dot
                    let headRect = CGRect(x: headX - 2, y: headY - 2, width: 4, height: 4)
                    context.fill(Path(ellipseIn: headRect), with: .color(.white.opacity(fade)))
                }

                // ── Drifting ships (2 staggered slots, less common) ──
                let shipIntervals: [Double] = [55.0, 80.0]
                for (si, interval) in shipIntervals.enumerated() {
                    let idx = Int(time / interval)
                    let t = time - Double(idx) * interval
                    let duration = 14.0
                    guard t < duration else { continue }

                    var seed = UInt64(idx &* 19349663 &+ si &* 83492791)
                    seed = seed ^ (seed >> 15)
                    let edge = Int(seed % 4)  // which screen edge to start from
                    seed = seed &* 6364136223846793005 &+ 1
                    let edgePos = CGFloat(seed % 1000) / 1000.0
                    seed = seed &* 6364136223846793005 &+ 1
                    let angle = Double(seed % 314) / 100.0 - 0.5 // slight angle variation

                    let progress = CGFloat(t / duration)
                    var sx: CGFloat, sy: CGFloat, dir: CGFloat

                    switch edge {
                    case 0: // from left
                        sx = -20 + (w + 40) * progress
                        sy = edgePos * h + CGFloat(sin(angle)) * 60
                        dir = 0
                    case 1: // from top
                        sx = edgePos * w + CGFloat(sin(angle)) * 60
                        sy = -20 + (h + 40) * progress
                        dir = .pi / 2
                    case 2: // from right
                        sx = w + 20 - (w + 40) * progress
                        sy = edgePos * h + CGFloat(sin(angle)) * 60
                        dir = .pi
                    default: // from bottom
                        sx = edgePos * w + CGFloat(sin(angle)) * 60
                        sy = h + 20 - (h + 40) * progress
                        dir = -.pi / 2
                    }

                    let fade = min(1.0, min(Double(progress) * 4, Double(1.0 - progress) * 4))

                    // Ship body — small diamond
                    let shipSize: CGFloat = 6
                    var ship = Path()
                    let cosD = CGFloat(cos(Double(dir)))
                    let sinD = CGFloat(sin(Double(dir)))
                    ship.move(to: CGPoint(x: sx + cosD * shipSize, y: sy + sinD * shipSize))       // nose
                    ship.addLine(to: CGPoint(x: sx - sinD * shipSize * 0.5, y: sy + cosD * shipSize * 0.5))
                    ship.addLine(to: CGPoint(x: sx - cosD * shipSize * 0.6, y: sy - sinD * shipSize * 0.6))
                    ship.addLine(to: CGPoint(x: sx + sinD * shipSize * 0.5, y: sy - cosD * shipSize * 0.5))
                    ship.closeSubpath()

                    context.fill(ship, with: .color(.white.opacity(fade * 0.5)))

                    // Tiny engine glow behind ship
                    let glowX = sx - cosD * shipSize * 0.8
                    let glowY = sy - sinD * shipSize * 0.8
                    let glowRect = CGRect(x: glowX - 2, y: glowY - 2, width: 4, height: 4)
                    context.fill(Path(ellipseIn: glowRect),
                                 with: .color(Color(hex: "60A5FA").opacity(fade * 0.6)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Tile Content Layer

    /// Deterministic random offset so clusters don't sit on a perfect grid.
    private func tileJitter(tx: Int, ty: Int, tileSize: CGFloat) -> CGPoint {
        var s = UInt64(abs(tx &* 73856093 ^ ty &* 19349663))
        s = s ^ (s >> 13)
        let jx = CGFloat(s % 1000) / 1000.0 - 0.5 // -0.5...0.5
        s = s &* 6364136223846793005 &+ 1
        let jy = CGFloat(s % 1000) / 1000.0 - 0.5
        let maxJitter = tileSize * 0.38
        return CGPoint(x: jx * maxJitter, y: jy * maxJitter)
    }

    private func tileContentLayer(size: CGSize) -> some View {
        let cx = viewModel.currentTileX
        let cy = viewModel.currentTileY
        let tileSize = viewModel.tileSize

        return ZStack {
            ForEach(-3...3, id: \.self) { dx in
                ForEach(-3...3, id: \.self) { dy in
                    let tx = cx + dx
                    let ty = cy + dy
                    let key = "\(tx),\(ty)"

                    // Tile centre in screen space + deterministic jitter
                    let jitter = tileJitter(tx: tx, ty: ty, tileSize: tileSize)
                    let centerX = CGFloat(tx) * tileSize + viewModel.voyagePosition.x + size.width / 2 + tileSize / 2 + jitter.x
                    let centerY = CGFloat(ty) * tileSize + viewModel.voyagePosition.y + size.height / 2 + tileSize / 2 + jitter.y

                    // Only render if roughly on screen
                    if centerX > -tileSize && centerX < size.width + tileSize &&
                       centerY > -tileSize && centerY < size.height + tileSize {

                        if let tile = viewModel.loadedTiles[key] {
                            VoyageClusterView(
                                tile: tile,
                                systemDiameter: compactDiameter,
                                interactive: false,
                                onSystemTap: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        zoomedTile = tile
                                    }
                                }
                            )
                            .position(x: centerX, y: centerY)
                            .transition(.scale.combined(with: .opacity))
                        } else if viewModel.loadingTileKeys.contains(key) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.03))
                                .frame(width: compactDiameter * 0.5, height: compactDiameter * 0.5)
                                .position(x: centerX, y: centerY)
                        }
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: viewModel.loadedTiles.count)
    }

    // MARK: - Zoomed Cluster Overlay

    private func zoomedOverlay(tile: VoyageTile, screenSize: CGSize) -> some View {
        let expandedDiameter = min(screenSize.width, screenSize.height) - 40

        return ZStack {
            // Dim background — tap to close
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        zoomedTile = nil
                    }
                }

            VStack(spacing: 20) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            zoomedTile = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Expanded solar system
                VoyageClusterView(
                    tile: tile,
                    systemDiameter: expandedDiameter,
                    interactive: true,
                    onItemTap: { item in
                        selectedItem = item
                    }
                )

                Spacer()
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.6)))
    }

    // MARK: - Pan Gesture

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard zoomedTile == nil else { return }
                let raw = CGSize(
                    width: value.translation.width - lastDragValue.width,
                    height: value.translation.height - lastDragValue.height
                )
                // Divide by zoom so panning distance matches finger movement at any scale
                let delta = CGSize(width: raw.width / zoomScale,
                                   height: raw.height / zoomScale)
                lastDragValue = value.translation
                viewModel.dragVelocity = CGSize(
                    width: value.velocity.width,
                    height: value.velocity.height
                )
                viewModel.updatePosition(translation: delta)
            }
            .onEnded { _ in
                lastDragValue = .zero
                withAnimation(.easeOut(duration: 0.5)) {
                    viewModel.dragVelocity = .zero
                }
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard zoomedTile == nil else { return }
                zoomScale = max(0.4, min(lastZoomScale * value, 3.0))
            }
            .onEnded { _ in
                lastZoomScale = zoomScale
            }
    }

    // MARK: - End Voyage Button

    private var endVoyageButton: some View {
        VStack {
            Spacer()
            Button {
                exitVoyage()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .bold))
                    Text("End Voyage")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .padding(.bottom, 50)
        }
    }

    // MARK: - Exit Animation

    private func exitVoyage() {
        viewModel.endVoyage()
        isExiting = true
        withAnimation(.easeIn(duration: 0.5)) {
            exitScale = 3.0
            exitOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }

    // MARK: - Star Generation

    private func generateStars(count: Int, size: CGSize) {
        stars = (0..<count).map { i in
            VoyageStar(
                id: i,
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 1...3),
                baseOpacity: Double.random(in: 0.2...0.8),
                twinkleSpeed: Double.random(in: 0.5...2.0),
                phaseOffset: Double.random(in: 0...(2 * .pi)),
                parallaxFactor: CGFloat.random(in: 0.02...0.15)
            )
        }
    }
}

// MARK: - Rocket Loading Animation

private struct VoyageRocketLoading: View {
    @State private var rocketOffset: CGFloat = 0
    @State private var flameScale: CGFloat = 1.0
    @State private var exhaustParticles: [ExhaustDot] = []

    private struct ExhaustDot: Identifiable {
        let id: Int
        let xJitter: CGFloat
        let size: CGFloat
        let delay: Double
        let isWhite: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                // Exhaust particles trailing below
                ForEach(exhaustParticles) { dot in
                    let color = dot.isWhite ? Color.white : Color(hex: "F97316")
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [color.opacity(0.7), color.opacity(0)],
                                center: .center, startRadius: 0, endRadius: dot.size
                            )
                        )
                        .frame(width: dot.size * 2, height: dot.size * 2)
                        .offset(x: dot.xJitter, y: 100 + CGFloat(dot.id) * 18)
                        .opacity(flameScale > 1.05 ? 0.8 : 0.35)
                        .animation(
                            .easeInOut(duration: 0.35 + dot.delay).repeatForever(autoreverses: true),
                            value: flameScale
                        )
                }

                // Outer orange flame glow
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "F97316").opacity(0.6),
                                Color(hex: "EF4444").opacity(0.3),
                                Color(hex: "EF4444").opacity(0)
                            ],
                            center: .center, startRadius: 4, endRadius: 50
                        )
                    )
                    .frame(width: 60, height: 100)
                    .scaleEffect(y: flameScale)
                    .offset(y: 70)

                // Inner white-hot flame core
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.95),
                                Color(hex: "FBBF24").opacity(0.7),
                                Color(hex: "F97316").opacity(0)
                            ],
                            center: .center, startRadius: 2, endRadius: 28
                        )
                    )
                    .frame(width: 36, height: 70)
                    .scaleEffect(y: flameScale)
                    .offset(y: 60)

                // Rocket body
                VStack(spacing: 0) {
                    // Nose cone
                    RocketNose()
                        .fill(
                            LinearGradient(colors: [.white, Color(hex: "B0B0B0")],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 44, height: 36)

                    // Body
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(colors: [Color(hex: "D4D4D4"), Color(hex: "4B4B4B")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: 48, height: 80)
                        .overlay(
                            VStack(spacing: 10) {
                                // Window
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [.white.opacity(0.9), Color(hex: "888888")],
                                            center: UnitPoint(x: 0.35, y: 0.35),
                                            startRadius: 0, endRadius: 10
                                        )
                                    )
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1))

                                // Stripe
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white.opacity(0.25))
                                    .frame(width: 36, height: 3)
                            }
                            .offset(y: -6)
                        )

                    // Fins
                    HStack(spacing: 30) {
                        RocketFin()
                            .fill(
                                LinearGradient(colors: [Color(hex: "9CA3AF"), Color(hex: "374151")],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .frame(width: 18, height: 32)
                        RocketFin()
                            .fill(
                                LinearGradient(colors: [Color(hex: "9CA3AF"), Color(hex: "374151")],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .frame(width: 18, height: 32)
                            .scaleEffect(x: -1)
                    }
                    .offset(y: -4)
                }
            }
            .offset(y: rocketOffset)

            Spacer()

            Text("Launching...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 100)
        }
        .onAppear {
            exhaustParticles = (0..<14).map { i in
                ExhaustDot(
                    id: i,
                    xJitter: CGFloat.random(in: -20...20),
                    size: CGFloat.random(in: 5...14),
                    delay: Double.random(in: 0...0.4),
                    isWhite: i % 3 == 0
                )
            }

            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                rocketOffset = -24
            }
            withAnimation(.easeInOut(duration: 0.25).repeatForever(autoreverses: true)) {
                flameScale = 1.35
            }
        }
    }
}

// Small rocket shape helpers
private struct RocketNose: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.midY))
        return p
    }
}

private struct RocketFin: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Item Detail Sheet

struct VoyageItemDetailSheet: View {
    let item: VoyageItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Type badge
                HStack {
                    Image(systemName: item.isMission ? "calendar.circle.fill" : "antenna.radiowaves.left.and.right")
                        .foregroundStyle(item.isMission
                            ? Color(hex: "3B82F6")
                            : Color(hex: "DB2777"))
                    Text(item.isMission ? "Mission" : "Flex Mission")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                // Title
                Text(item.displayTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Description
                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Tags
                if !item.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(item.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: "8B5CF6").opacity(0.12))
                                    .foregroundColor(Color(hex: "8B5CF6"))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Details
                VStack(spacing: 12) {
                    if let date = item.date, !date.isEmpty {
                        detailRow(icon: "calendar", text: date)
                    }
                    if let location = item.location, !location.isEmpty {
                        detailRow(icon: "mappin.circle", text: location)
                    }
                    if let min = item.minGroupSize, let max = item.maxGroupSize {
                        detailRow(icon: "person.2", text: "\(min)–\(max) people")
                    } else if let size = item.maxPodSize {
                        detailRow(icon: "person.2", text: "Up to \(size) people")
                    }
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}
