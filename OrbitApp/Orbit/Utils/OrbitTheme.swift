//
//  OrbitTheme.swift
//  Orbit
//
//  Shared design tokens, reusable components, and layout helpers.
//

import SwiftUI

// MARK: - Colors & Gradients

enum OrbitTheme {
    static let pink   = Color(red: 0.9,  green: 0.6,  blue: 0.7)
    static let purple = Color(red: 0.7,  green: 0.65, blue: 0.85)
    static let blue   = Color(red: 0.45, green: 0.55, blue: 0.85)

    /// Horizontal signature gradient used for text accents and dividers
    static let gradient = LinearGradient(
        colors: [pink, purple, blue],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Diagonal gradient used for filled buttons and FABs
    static let gradientFill = LinearGradient(
        colors: [Color(red: 0.55, green: 0.6, blue: 0.85),
                 Color(red: 0.85, green: 0.55, blue: 0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Dark card background
    static let cardGradient = LinearGradient(
        colors: [Color(red: 0.08, green: 0.08, blue: 0.18),
                 Color(red: 0.13, green: 0.08, blue: 0.24)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Tag Chip

struct TagChip: View {
    let text: String
    var onRemove: (() -> Void)? = nil
    var darkBackground: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(darkBackground ? AnyShapeStyle(Color.white.opacity(0.85)) : AnyShapeStyle(OrbitTheme.gradient))
        .background(darkBackground ? Color.white.opacity(0.15) : OrbitTheme.purple.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Flow Layout (wrapping tag chips)

struct TagFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x + sz.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowH: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

// MARK: - Section Header

struct OrbitSectionHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Capsule()
                .fill(OrbitTheme.gradient)
                .frame(width: 28, height: 2.5)
        }
    }
}

// MARK: - Card Press Style

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Wavy Line Shape (shared by LaunchView + AuthFlowView)

struct WavyLineShape: Shape {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let waveHeight: CGFloat
    let frequency: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: startPoint)
        let deltaX = endPoint.x - startPoint.x
        let deltaY = endPoint.y - startPoint.y
        let steps = 80
        for i in 1...steps {
            let progress = CGFloat(i) / CGFloat(steps)
            let x = startPoint.x + deltaX * progress
            let baseY = startPoint.y + deltaY * progress
            let wave = sin(progress * .pi * 2 * frequency) * waveHeight
            path.addLine(to: CGPoint(x: x, y: baseY + wave))
        }
        return path
    }
}
