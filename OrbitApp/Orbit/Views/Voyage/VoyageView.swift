//
//  VoyageView.swift
//  Orbit
//
//  Fullscreen infinite 2D exploration — panning through tile-based clusters
//  of missions and signals against a dense parallax star field.
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

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Pure black background
                Color.black.ignoresSafeArea()

                // Parallax star field
                starFieldLayer(size: geo.size)

                // Tile content layer — moves with pan
                tileContentLayer(size: geo.size)

                // Home direction indicator
                if viewModel.distanceFromHome > 2 {
                    VoyageHomeIndicator(angle: viewModel.homeAngle)
                }

                // End Voyage button
                endVoyageButton

                // Loading indicator for initial load
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
            .scaleEffect(isExiting ? exitScale : entryScale)
            .opacity(isExiting ? exitOpacity : entryOpacity)
            .onAppear {
                screenSize = geo.size
                generateStars(count: 300, size: geo.size)
                withAnimation(.easeOut(duration: 0.6)) {
                    entryScale = 1.0
                    entryOpacity = 1.0
                }
            }
            .gesture(panGesture)
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

                for star in stars {
                    // Parallax offset
                    let px = viewModel.voyagePosition.x * star.parallaxFactor
                    let py = viewModel.voyagePosition.y * star.parallaxFactor

                    // Wrap star position
                    var sx = (star.x * canvasSize.width + px).truncatingRemainder(dividingBy: canvasSize.width)
                    var sy = (star.y * canvasSize.height + py).truncatingRemainder(dividingBy: canvasSize.height)
                    if sx < 0 { sx += canvasSize.width }
                    if sy < 0 { sy += canvasSize.height }

                    // Twinkle
                    let twinkle = (sin(time * star.twinkleSpeed + star.phaseOffset) + 1) / 2
                    let opacity = star.baseOpacity + twinkle * (1.0 - star.baseOpacity)

                    if warpFactor > 0.1 {
                        // Warp-speed streaks: elongate in direction of movement
                        let streakLength = star.size + warpFactor * 12
                        let angle = atan2(-velocity.height, -velocity.width)

                        let dx = cos(angle) * streakLength / 2
                        let dy = sin(angle) * streakLength / 2

                        var path = Path()
                        path.move(to: CGPoint(x: sx - dx, y: sy - dy))
                        path.addLine(to: CGPoint(x: sx + dx, y: sy + dy))

                        context.stroke(
                            path,
                            with: .color(.white.opacity(opacity * 0.8)),
                            lineWidth: star.size * 0.6
                        )
                    } else {
                        // Normal dot
                        let rect = CGRect(
                            x: sx - star.size / 2,
                            y: sy - star.size / 2,
                            width: star.size,
                            height: star.size
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(.white.opacity(opacity))
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Tile Content Layer

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

                    // Tile origin in world space, offset by voyage position
                    let originX = CGFloat(tx) * tileSize + viewModel.voyagePosition.x + size.width / 2
                    let originY = CGFloat(ty) * tileSize + viewModel.voyagePosition.y + size.height / 2

                    // Only render if tile is roughly on screen
                    if originX > -tileSize && originX < size.width + tileSize &&
                       originY > -tileSize && originY < size.height + tileSize {

                        if let tile = viewModel.loadedTiles[key] {
                            VoyageClusterView(
                                tile: tile,
                                tileSize: tileSize,
                                onItemTap: { item in
                                    selectedItem = item
                                }
                            )
                            .frame(width: tileSize, height: tileSize)
                            .position(x: originX + tileSize / 2, y: originY + tileSize / 2)
                            .transition(.scale.combined(with: .opacity))
                        } else if viewModel.loadingTileKeys.contains(key) {
                            // Subtle loading shimmer
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.03))
                                .frame(width: tileSize * 0.6, height: tileSize * 0.6)
                                .position(x: originX + tileSize / 2, y: originY + tileSize / 2)
                        }
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: viewModel.loadedTiles.count)
    }

    // MARK: - Pan Gesture

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let delta = CGSize(
                    width: value.translation.width - lastDragValue.width,
                    height: value.translation.height - lastDragValue.height
                )
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
