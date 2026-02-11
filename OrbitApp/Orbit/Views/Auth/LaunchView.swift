//
//  LaunchView.swift
//  Orbit
//
//  Launch screen with logo and LAUNCH button.
//

import SwiftUI

struct LaunchView: View {
    let onLaunch: () -> Void

    var body: some View {
        ZStack {
            // White background
            Color.white.ignoresSafeArea()

            // Top wavy lines
            VStack {
                TopWavyLines()
                    .frame(height: 180)
                Spacer()
            }
            .ignoresSafeArea()

            // Bottom wavy lines
            VStack {
                Spacer()
                BottomWavyLines()
                    .frame(height: 200)
            }
            .ignoresSafeArea()

            // Sparkles near top right (close to the lines)
            VStack {
                HStack {
                    Spacer()
                    SparklesView()
                        .padding(.top, 55)
                        .padding(.trailing, 40)
                }
                Spacer()
            }

            // Main content
            VStack(spacing: 30) {
                Spacer()

                // Logo
                Image("OrbitLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 280)

                Spacer()

                // Launch button
                Button(action: onLaunch) {
                    Text("L A U N C H !")
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .tracking(2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.9, green: 0.65, blue: 0.72),
                                    Color(red: 0.7, green: 0.68, blue: 0.85),
                                    Color(red: 0.5, green: 0.58, blue: 0.82)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.horizontal, 35)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                }

                Spacer()
                    .frame(height: 100)
            }
        }
    }
}

// MARK: - Top Wavy Lines

struct TopWavyLines: View {
    private let gradient = LinearGradient(
        colors: [
            Color(red: 0.9, green: 0.6, blue: 0.7),
            Color(red: 0.7, green: 0.65, blue: 0.85),
            Color(red: 0.45, green: 0.55, blue: 0.85)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Line 1 - Pink (bottom of the three)
                WavyLinePath(
                    startPoint: CGPoint(x: -20, y: geo.size.height - 20),
                    endPoint: CGPoint(x: geo.size.width + 20, y: 80),
                    waveHeight: 15,
                    frequency: 1.2
                )
                .stroke(gradient, lineWidth: 2.5)

                // Line 2 - Purple (middle)
                WavyLinePath(
                    startPoint: CGPoint(x: -20, y: geo.size.height - 50),
                    endPoint: CGPoint(x: geo.size.width + 20, y: 50),
                    waveHeight: 12,
                    frequency: 1.5
                )
                .stroke(gradient, lineWidth: 2.5)

                // Line 3 - Blue (top)
                WavyLinePath(
                    startPoint: CGPoint(x: -20, y: geo.size.height - 80),
                    endPoint: CGPoint(x: geo.size.width + 20, y: 20),
                    waveHeight: 18,
                    frequency: 1.0
                )
                .stroke(gradient, lineWidth: 2.5)
            }
        }
    }
}

// MARK: - Bottom Wavy Lines

struct BottomWavyLines: View {
    private let gradient = LinearGradient(
        colors: [
            Color(red: 0.9, green: 0.6, blue: 0.7),
            Color(red: 0.7, green: 0.65, blue: 0.85),
            Color(red: 0.45, green: 0.55, blue: 0.85)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Line 1 - Pink (top of the three)
                WavyLinePath(
                    startPoint: CGPoint(x: -20, y: 30),
                    endPoint: CGPoint(x: geo.size.width + 20, y: geo.size.height - 60),
                    waveHeight: 18,
                    frequency: 1.3
                )
                .stroke(gradient, lineWidth: 2.5)

                // Line 2 - Purple (middle)
                WavyLinePath(
                    startPoint: CGPoint(x: -20, y: 70),
                    endPoint: CGPoint(x: geo.size.width + 20, y: geo.size.height - 30),
                    waveHeight: 15,
                    frequency: 1.6
                )
                .stroke(gradient, lineWidth: 2.5)

                // Line 3 - Blue (bottom)
                WavyLinePath(
                    startPoint: CGPoint(x: -20, y: 110),
                    endPoint: CGPoint(x: geo.size.width + 20, y: geo.size.height),
                    waveHeight: 20,
                    frequency: 1.1
                )
                .stroke(gradient, lineWidth: 2.5)
            }
        }
    }
}

// MARK: - Wavy Line Path

struct WavyLinePath: Shape {
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

// MARK: - Sparkles

struct SparklesView: View {
    var body: some View {
        Canvas { context, size in
            // Draw 3 four-pointed stars
            drawStar(context: context, center: CGPoint(x: 20, y: 15), size: 18)
            drawStar(context: context, center: CGPoint(x: 45, y: 5), size: 10)
            drawStar(context: context, center: CGPoint(x: 35, y: 35), size: 12)
        }
        .frame(width: 60, height: 50)
    }

    private func drawStar(context: GraphicsContext, center: CGPoint, size: CGFloat) {
        var path = Path()

        // Vertical line
        path.move(to: CGPoint(x: center.x, y: center.y - size/2))
        path.addLine(to: CGPoint(x: center.x, y: center.y + size/2))

        // Horizontal line
        path.move(to: CGPoint(x: center.x - size/2, y: center.y))
        path.addLine(to: CGPoint(x: center.x + size/2, y: center.y))

        context.stroke(path, with: .color(.black), lineWidth: 1.5)
    }
}

#Preview {
    LaunchView(onLaunch: {})
}
