//
//  VoyageClusterView.swift
//  Orbit
//
//  Renders a single tile's cluster as a mini solar system — a glowing sun
//  at the centre with orbit rings that rotate, each carrying a planet bubble.
//

import SwiftUI

struct VoyageClusterView: View {
    let tile: VoyageTile
    let tileSize: CGFloat
    var onItemTap: (VoyageItem) -> Void

    @State private var appeared = false

    /// Deterministic seed for this tile (layout, rotation speeds, sun hue).
    private var seed: UInt64 {
        UInt64(abs(tile.x &* 73856093 ^ tile.y &* 19349663))
    }

    /// Sun colour derived from tile coordinates.
    private var sunColor: Color {
        let hues: [Color] = [
            Color(hex: "FBBF24"), // warm gold
            Color(hex: "F97316"), // orange
            Color(hex: "FB923C"), // light orange
            Color(hex: "FCD34D"), // yellow
        ]
        return hues[Int(seed) % sunHueCount]
    }
    private let sunHueCount = 4

    /// Sun radius scales with item count so bigger systems feel heavier.
    private var sunRadius: CGFloat {
        CGFloat(22 + min(tile.items.count, 6) * 3)
    }

    /// Max orbit radius — keep planets inside the tile.
    private var maxOrbitRadius: CGFloat {
        tileSize * 0.42
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let center = tileSize / 2

            Canvas { context, size in
                // Draw orbit ring strokes
                for index in 0..<tile.items.count {
                    let radius = orbitRadius(for: index)
                    let rect = CGRect(
                        x: center - radius,
                        y: center - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(0.08)),
                        lineWidth: 0.5
                    )
                }

                // Draw sun glow
                let glowRect = CGRect(
                    x: center - sunRadius * 2,
                    y: center - sunRadius * 2,
                    width: sunRadius * 4,
                    height: sunRadius * 4
                )
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .radialGradient(
                        Gradient(colors: [sunColor.opacity(0.35), sunColor.opacity(0)]),
                        center: CGPoint(x: center, y: center),
                        startRadius: sunRadius * 0.5,
                        endRadius: sunRadius * 2
                    )
                )

                // Draw sun core
                let sunRect = CGRect(
                    x: center - sunRadius,
                    y: center - sunRadius,
                    width: sunRadius * 2,
                    height: sunRadius * 2
                )
                context.fill(
                    Path(ellipseIn: sunRect),
                    with: .radialGradient(
                        Gradient(colors: [.white.opacity(0.95), sunColor]),
                        center: CGPoint(x: center, y: center),
                        startRadius: 0,
                        endRadius: sunRadius
                    )
                )
            }
            .allowsHitTesting(false)

            // Planet bubbles positioned on their orbits
            ForEach(Array(tile.items.enumerated()), id: \.element.id) { index, item in
                let radius = orbitRadius(for: index)
                let speed = orbitSpeed(for: index)
                let startAngle = orbitStartAngle(for: index)
                let angle = startAngle + time * speed

                let px = center + radius * CGFloat(cos(angle))
                let py = center + radius * CGFloat(sin(angle))

                VoyageBubble(item: item) {
                    onItemTap(item)
                }
                .position(x: px, y: py)
                .scaleEffect(appeared ? 1 : 0.3)
                .opacity(appeared ? 1 : 0)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.7)
                        .delay(Double(index) * 0.08),
                    value: appeared
                )
            }
        }
        .frame(width: tileSize, height: tileSize)
        .onAppear { appeared = true }
    }

    // MARK: - Orbit Helpers

    /// Radius for the nth orbit ring, evenly spaced from sun edge to max.
    private func orbitRadius(for index: Int) -> CGFloat {
        let count = max(tile.items.count, 1)
        let innerEdge = sunRadius + 30
        let step = (maxOrbitRadius - innerEdge) / CGFloat(count)
        return innerEdge + step * CGFloat(index) + step * 0.5
    }

    /// Angular speed (radians/sec) — inner orbits faster, outer slower.
    private func orbitSpeed(for index: Int) -> Double {
        let base = 0.18 + Double(seed % 10) * 0.008 // slight per-tile variation
        let count = max(tile.items.count, 1)
        // Inner = faster, outer = slower, alternating directions
        let factor = 1.0 - Double(index) * 0.12 / Double(count)
        let direction: Double = index.isMultiple(of: 2) ? 1 : -1
        return base * factor * direction
    }

    /// Deterministic start angle so planets aren't all aligned on load.
    private func orbitStartAngle(for index: Int) -> Double {
        var s = seed &+ UInt64(index) &* 2654435761
        s = s ^ (s >> 13)
        return Double(s % 6283) / 1000.0 // 0 ... ~2pi
    }
}

// MARK: - Voyage Bubble

struct VoyageBubble: View {
    let item: VoyageItem
    let onTap: () -> Void

    @State private var isFloating = false

    private var bubbleColor: Color {
        if item.isMission {
            let hash = abs(item.id.hashValue)
            let colors: [Color] = [
                Color(hex: "3B82F6"),  // blue
                Color(hex: "0D9488"),  // teal
                Color(hex: "059669"),  // green
            ]
            return colors[hash % colors.count]
        } else {
            let hash = abs(item.id.hashValue)
            let colors: [Color] = [
                Color(hex: "D97706"),  // amber
                Color(hex: "DB2777"),  // pink
                Color(hex: "8B5CF6"),  // lavender
            ]
            return colors[hash % colors.count]
        }
    }

    private var bubbleSize: CGFloat {
        let hash = abs(item.id.hashValue)
        return CGFloat(44 + (hash % 16))
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [bubbleColor.opacity(0.4), bubbleColor.opacity(0)],
                            center: .center,
                            startRadius: bubbleSize * 0.3,
                            endRadius: bubbleSize * 0.8
                        )
                    )
                    .frame(width: bubbleSize * 1.6, height: bubbleSize * 1.6)

                // Main bubble
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [bubbleColor.opacity(0.9), bubbleColor.opacity(0.5)],
                            center: UnitPoint(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: bubbleSize * 0.5
                        )
                    )
                    .frame(width: bubbleSize, height: bubbleSize)
                    .overlay(
                        Circle()
                            .strokeBorder(bubbleColor.opacity(0.6), lineWidth: 1.5)
                    )

                // Icon
                VStack(spacing: 2) {
                    Image(systemName: item.isMission ? "calendar" : "antenna.radiowaves.left.and.right")
                        .font(.system(size: bubbleSize * 0.24))
                        .foregroundColor(.white)

                    if bubbleSize > 50 {
                        Text(item.displayTitle)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(width: bubbleSize * 0.75)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .offset(y: isFloating ? -2 : 2)
        .animation(
            .easeInOut(duration: Double.random(in: 2.5...4.0)).repeatForever(autoreverses: true),
            value: isFloating
        )
        .onAppear {
            isFloating = true
        }
    }
}
