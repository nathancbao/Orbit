//
//  VoyageClusterView.swift
//  Orbit
//
//  Renders a single tile's cluster as a mini solar system — a glowing sun
//  at the centre with orbit rings that rotate, each carrying a planet bubble.
//  Accepts a `systemDiameter` so the same view works at compact and zoomed sizes.
//

import SwiftUI

struct VoyageClusterView: View {
    let tile: VoyageTile
    let systemDiameter: CGFloat
    let interactive: Bool
    var onSystemTap: (() -> Void)? = nil
    var onItemTap: ((VoyageItem) -> Void)? = nil

    @State private var appeared = false

    // MARK: - Deterministic seed

    private var seed: UInt64 {
        UInt64(abs(tile.x &* 73856093 ^ tile.y &* 19349663))
    }

    // MARK: - Sun

    private var sunColor: Color {
        let hues: [Color] = [
            Color(hex: "FBBF24"), // warm gold
            Color(hex: "F97316"), // orange
            Color(hex: "FB923C"), // light orange
            Color(hex: "FCD34D"), // yellow
        ]
        return hues[Int(seed) % hues.count]
    }

    private var sunRadius: CGFloat {
        let base: CGFloat = 10 + CGFloat(min(tile.items.count, 6)) * 1.5
        return base * scaleFactor
    }

    // MARK: - Geometry helpers

    private var scaleFactor: CGFloat { systemDiameter / 300 }
    private var center: CGFloat { systemDiameter / 2 }
    private var maxOrbitRadius: CGFloat { systemDiameter * 0.48 }

    // MARK: - Body

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                // Canvas — orbit rings + sun (non-interactive)
                Canvas { context, _ in
                    drawOrbitRings(context: context)
                    drawSun(context: context)
                }
                .allowsHitTesting(false)

                // Planet bubbles
                ForEach(Array(tile.items.enumerated()), id: \.element.id) { index, item in
                    let radius = orbitRadius(for: index)
                    let angle = orbitStartAngle(for: index) + time * orbitSpeed(for: index)
                    let px = center + radius * CGFloat(cos(angle))
                    let py = center + radius * CGFloat(sin(angle))

                    VoyageBubble(item: item, scale: scaleFactor, showLabel: interactive) {
                        if interactive { onItemTap?(item) }
                    }
                    .position(x: px, y: py)
                    .allowsHitTesting(interactive)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7)
                            .delay(Double(index) * 0.08),
                        value: appeared
                    )
                }
            }
        }
        .frame(width: systemDiameter, height: systemDiameter)
        .contentShape(Circle())
        .onTapGesture {
            if !interactive { onSystemTap?() }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Canvas drawing

    private func drawOrbitRings(context: GraphicsContext) {
        for index in 0..<tile.items.count {
            let r = orbitRadius(for: index)
            let rect = CGRect(x: center - r, y: center - r, width: r * 2, height: r * 2)
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(interactive ? 0.22 : 0.15)),
                lineWidth: interactive ? 1.0 : 0.7
            )
        }
    }

    private func drawSun(context: GraphicsContext) {
        let c = CGPoint(x: center, y: center)

        // Outer glow
        let glowR = sunRadius * 2.5
        context.fill(
            Path(ellipseIn: CGRect(x: c.x - glowR, y: c.y - glowR,
                                   width: glowR * 2, height: glowR * 2)),
            with: .radialGradient(
                Gradient(colors: [sunColor.opacity(0.35), sunColor.opacity(0)]),
                center: c, startRadius: sunRadius * 0.4, endRadius: glowR
            )
        )

        // Core
        context.fill(
            Path(ellipseIn: CGRect(x: c.x - sunRadius, y: c.y - sunRadius,
                                   width: sunRadius * 2, height: sunRadius * 2)),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.95), sunColor]),
                center: c, startRadius: 0, endRadius: sunRadius
            )
        )
    }

    // MARK: - Orbit helpers

    private func orbitRadius(for index: Int) -> CGFloat {
        let count = max(tile.items.count, 1)
        let innerEdge = sunRadius + systemDiameter * 0.06
        let step = (maxOrbitRadius - innerEdge) / CGFloat(count)
        return innerEdge + step * CGFloat(index) + step * 0.5
    }

    /// Slow orbit — inner rings faster, alternating directions.
    private func orbitSpeed(for index: Int) -> Double {
        let base = 0.035 + Double(seed % 10) * 0.002
        let count = max(tile.items.count, 1)
        let factor = 1.0 - Double(index) * 0.1 / Double(count)
        let direction: Double = index.isMultiple(of: 2) ? 1 : -1
        return base * factor * direction
    }

    private func orbitStartAngle(for index: Int) -> Double {
        var s = seed &+ UInt64(index) &* 2654435761
        s = s ^ (s >> 13)
        return Double(s % 6283) / 1000.0
    }
}

// MARK: - Voyage Bubble

struct VoyageBubble: View {
    let item: VoyageItem
    let scale: CGFloat
    let showLabel: Bool
    let onTap: () -> Void

    @State private var isFloating = false

    private var bubbleColor: Color {
        let hash = abs(item.id.hashValue)
        if item.isMission {
            let colors: [Color] = [
                Color(hex: "3B82F6"),
                Color(hex: "0D9488"),
                Color(hex: "059669"),
            ]
            return colors[hash % colors.count]
        } else {
            let colors: [Color] = [
                Color(hex: "D97706"),
                Color(hex: "DB2777"),
                Color(hex: "8B5CF6"),
            ]
            return colors[hash % colors.count]
        }
    }

    private var bubbleSize: CGFloat {
        let hash = abs(item.id.hashValue)
        return CGFloat(44 + (hash % 16)) * scale
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

                // Core
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

                // Icon + label
                VStack(spacing: 2) {
                    Image(systemName: item.isMission ? "calendar" : "antenna.radiowaves.left.and.right")
                        .font(.system(size: bubbleSize * 0.24))
                        .foregroundColor(.white)

                    if showLabel && bubbleSize > 36 {
                        Text(item.displayTitle)
                            .font(.system(size: max(7, bubbleSize * 0.15), weight: .medium))
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
            .easeInOut(duration: Double.random(in: 2.5...4.0))
                .repeatForever(autoreverses: true),
            value: isFloating
        )
        .onAppear { isFloating = true }
    }
}
