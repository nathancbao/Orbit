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

            // Stars near top right (close to the lines)
            VStack {
                HStack {
                    Spacer()
                    BlackStarsView()
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
                        .foregroundStyle(OrbitTheme.gradient)
                        .padding(.horizontal, 35)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.black, lineWidth: 1)
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
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Line 1 - Pink (bottom of the three)
                WavyLineShape(
                    startPoint: CGPoint(x: -20, y: geo.size.height - 20),
                    endPoint: CGPoint(x: geo.size.width + 20, y: 80),
                    waveHeight: 15,
                    frequency: 1.2
                )
                .stroke(OrbitTheme.gradient, lineWidth: 2.5)

                // Line 2 - Purple (middle)
                WavyLineShape(
                    startPoint: CGPoint(x: -20, y: geo.size.height - 50),
                    endPoint: CGPoint(x: geo.size.width + 20, y: 50),
                    waveHeight: 12,
                    frequency: 1.5
                )
                .stroke(OrbitTheme.gradient, lineWidth: 2.5)

                // Line 3 - Blue (top)
                WavyLineShape(
                    startPoint: CGPoint(x: -20, y: geo.size.height - 80),
                    endPoint: CGPoint(x: geo.size.width + 20, y: 20),
                    waveHeight: 18,
                    frequency: 1.0
                )
                .stroke(OrbitTheme.gradient, lineWidth: 2.5)
            }
        }
    }
}

// MARK: - Bottom Wavy Lines

struct BottomWavyLines: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Line 1 - Pink (top of the three)
                WavyLineShape(
                    startPoint: CGPoint(x: -20, y: 30),
                    endPoint: CGPoint(x: geo.size.width + 20, y: geo.size.height - 60),
                    waveHeight: 18,
                    frequency: 1.3
                )
                .stroke(OrbitTheme.gradient, lineWidth: 2.5)

                // Line 2 - Purple (middle)
                WavyLineShape(
                    startPoint: CGPoint(x: -20, y: 70),
                    endPoint: CGPoint(x: geo.size.width + 20, y: geo.size.height - 30),
                    waveHeight: 15,
                    frequency: 1.6
                )
                .stroke(OrbitTheme.gradient, lineWidth: 2.5)

                // Line 3 - Blue (bottom)
                WavyLineShape(
                    startPoint: CGPoint(x: -20, y: 110),
                    endPoint: CGPoint(x: geo.size.width + 20, y: geo.size.height),
                    waveHeight: 20,
                    frequency: 1.1
                )
                .stroke(OrbitTheme.gradient, lineWidth: 2.5)
            }
        }
    }
}


// MARK: - Black Stars

struct BlackStarsView: View {
    var body: some View {
        ZStack {
            Image("blackStar")
                .resizable()
                .frame(width: 18, height: 18)
                .offset(x: -10, y: -5)
            Image("blackStar")
                .resizable()
                .frame(width: 10, height: 10)
                .offset(x: 15, y: -15)
            Image("blackStar")
                .resizable()
                .frame(width: 12, height: 12)
                .offset(x: 5, y: 15)
        }
        .frame(width: 60, height: 50)
    }
}

#Preview {
    LaunchView(onLaunch: {})
}
