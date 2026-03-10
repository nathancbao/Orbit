//
//  VoyageClusterView.swift
//  Orbit
//
//  Renders a single tile's cluster of activity bubbles in an organic scatter.
//

import SwiftUI

struct VoyageClusterView: View {
    let tile: VoyageTile
    let tileSize: CGFloat
    var onItemTap: (VoyageItem) -> Void

    @State private var appeared = false

    var body: some View {
        let positions = VoyageViewModel.scatterPositions(
            tileX: tile.x, tileY: tile.y, count: tile.items.count
        )

        ZStack {
            ForEach(Array(tile.items.enumerated()), id: \.element.id) { index, item in
                if index < positions.count {
                    let pos = positions[index]
                    VoyageBubble(item: item) {
                        onItemTap(item)
                    }
                    .position(
                        x: pos.x * tileSize,
                        y: pos.y * tileSize
                    )
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
        .onAppear {
            appeared = true
        }
    }
}

// MARK: - Voyage Bubble

struct VoyageBubble: View {
    let item: VoyageItem
    let onTap: () -> Void

    @State private var isFloating = false

    private var bubbleColor: Color {
        if item.isMission {
            // Deterministic color from id hash
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
        // Slightly varied sizes based on id hash
        let hash = abs(item.id.hashValue)
        return CGFloat(60 + (hash % 20))
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
                        .font(.system(size: bubbleSize * 0.22))
                        .foregroundColor(.white)

                    if bubbleSize > 65 {
                        Text(item.displayTitle)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(width: bubbleSize * 0.7)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .offset(y: isFloating ? -3 : 3)
        .animation(
            .easeInOut(duration: Double.random(in: 2.5...4.0)).repeatForever(autoreverses: true),
            value: isFloating
        )
        .onAppear {
            isFloating = true
        }
    }
}
