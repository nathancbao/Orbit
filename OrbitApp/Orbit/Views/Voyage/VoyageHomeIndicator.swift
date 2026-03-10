//
//  VoyageHomeIndicator.swift
//  Orbit
//
//  Edge-of-screen arrow pointing back toward origin (0,0).
//

import SwiftUI

struct VoyageHomeIndicator: View {
    let angle: CGFloat  // radians, pointing toward origin

    @State private var pulse = false

    // Inset from screen edge
    private let edgeInset: CGFloat = 40

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let position = edgePosition(center: center, size: geo.size)

            VStack(spacing: 2) {
                Image(systemName: "house.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                    .rotationEffect(.radians(Double(angle) + .pi / 2))
            }
            .padding(10)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.6, blue: 0.85),
                                Color(red: 0.85, green: 0.55, blue: 0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(red: 0.55, green: 0.6, blue: 0.85).opacity(0.5), radius: 8)
            )
            .scaleEffect(pulse ? 1.1 : 1.0)
            .opacity(0.9)
            .position(position)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
        }
        .allowsHitTesting(false)
    }

    /// Calculate position on the screen edge at the given angle.
    private func edgePosition(center: CGPoint, size: CGSize) -> CGPoint {
        let hw = size.width / 2 - edgeInset
        let hh = size.height / 2 - edgeInset

        let cos_a = cos(angle)
        let sin_a = sin(angle)

        // Find where the ray from center at `angle` hits the screen rect
        var t: CGFloat = .greatestFiniteMagnitude

        if cos_a != 0 {
            let tx = (cos_a > 0 ? hw : -hw) / cos_a
            if tx > 0 { t = min(t, tx) }
        }
        if sin_a != 0 {
            let ty = (sin_a > 0 ? hh : -hh) / sin_a
            if ty > 0 { t = min(t, ty) }
        }

        return CGPoint(
            x: center.x + cos_a * t,
            y: center.y + sin_a * t
        )
    }
}
