//
//  AuthFlowView.swift
//  Orbit
//
//  Email verification flow for .edu emails.
//

import SwiftUI

struct AuthFlowView: View {
    @StateObject private var viewModel = AuthViewModel()
    let onAuthComplete: (Bool) -> Void // passes isNewUser

    var body: some View {
        ZStack {
            // White background
            Color.white.ignoresSafeArea()

            // Content based on auth state
            switch viewModel.authState {
            case .emailEntry:
                emailEntryView
            case .verification:
                verificationView
            case .authenticated:
                ProgressView()
                    .onAppear {
                        onAuthComplete(viewModel.isNewUser)
                    }
            }
        }
    }

    // MARK: - Email Entry View (New Design)

    private var emailEntryView: some View {
        ZStack {
            // Decorative wavy lines at bottom
            VStack {
                Spacer()
                WavyLinesView()
                    .frame(height: 200)
            }
            .ignoresSafeArea()

            // Main content
            VStack(spacing: 24) {
                Spacer()

                // Graduation cap icon
                GraduationCapIcon()

                // Title text
                Text("type in your student email!")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.black)

                // Email text field
                TextField("youremail@university.edu", text: $viewModel.email)
                    .textFieldStyle(.plain)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, design: .monospaced))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.black.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 40)

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()
                Spacer()
            }

            // Arrow button at bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    GradientArrowButton(isLoading: viewModel.isLoading, isEnabled: viewModel.isEmailValid) {
                        Task {
                            await viewModel.sendVerificationCode()
                        }
                    }
                    .padding(.trailing, 30)
                    .padding(.bottom, 50)
                }
            }
        }
    }

    // MARK: - Verification View (Updated to match style)

    private var verificationView: some View {
        ZStack {
            // Decorative wavy lines at bottom
            VStack {
                Spacer()
                WavyLinesView()
                    .frame(height: 200)
            }
            .ignoresSafeArea()

            // Main content
            VStack(spacing: 24) {
                Spacer()

                // Envelope icon with rays
                VerificationIcon()
                    .frame(width: 120, height: 120)

                // Title text
                Text("check your inbox!")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.black)

                Text(viewModel.email)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.gray)

                // Code text field
                TextField("000000", text: $viewModel.verificationCode)
                    .textFieldStyle(.plain)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.black.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 60)

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button(action: {
                    viewModel.resetToEmailEntry()
                }) {
                    Text("change email")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                }

                Spacer()
                Spacer()
            }

            // Arrow button at bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    GradientArrowButton(isLoading: viewModel.isLoading, isEnabled: viewModel.isCodeValid) {
                        Task {
                            await viewModel.verifyCode()
                        }
                    }
                    .padding(.trailing, 30)
                    .padding(.bottom, 50)
                }
            }
        }
    }
}

// MARK: - Graduation Cap Icon

struct GraduationCapIcon: View {
    // Define colors as properties to help compiler
    private let blueColor = Color(red: 0.55, green: 0.55, blue: 0.85)
    private let pinkColor = Color(red: 0.9, green: 0.5, blue: 0.65)

    var body: some View {
        ZStack {
            // Mortarboard top (diamond shape) - gradient stroke
            GraduationCapShape()
                .stroke(
                    LinearGradient(
                        colors: [blueColor, pinkColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 3.5
                )
                .frame(width: 130, height: 130)
        }
    }
}

// Separate shape for the graduation cap
struct GraduationCapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.midX
        let centerY = rect.midY

        // Diamond top (mortarboard)
        path.move(to: CGPoint(x: centerX, y: centerY - 30))
        path.addLine(to: CGPoint(x: centerX + 55, y: centerY))
        path.addLine(to: CGPoint(x: centerX, y: centerY + 18))
        path.addLine(to: CGPoint(x: centerX - 55, y: centerY))
        path.closeSubpath()

        // Base (curved part that sits on head)
        path.move(to: CGPoint(x: centerX - 35, y: centerY + 18))
        path.addLine(to: CGPoint(x: centerX - 30, y: centerY + 42))
        path.addQuadCurve(
            to: CGPoint(x: centerX + 30, y: centerY + 42),
            control: CGPoint(x: centerX, y: centerY + 50)
        )
        path.addLine(to: CGPoint(x: centerX + 35, y: centerY + 18))

        return path
    }
}

// MARK: - Verification Icon

struct VerificationIcon: View {
    private let blueColor = Color(red: 0.55, green: 0.55, blue: 0.85)
    private let pinkColor = Color(red: 0.9, green: 0.5, blue: 0.65)

    var body: some View {
        EnvelopeShape()
            .stroke(
                LinearGradient(
                    colors: [blueColor, pinkColor],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 3.5
            )
            .frame(width: 120, height: 85)
    }
}

struct EnvelopeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Envelope body (rectangle with straight top)
        path.addRect(CGRect(x: 0, y: 0, width: w, height: h))

        // Inner V flap
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.5))
        path.addLine(to: CGPoint(x: w, y: 0))

        return path
    }
}

// MARK: - Wavy Lines Background

struct WavyLinesView: View {
    private let gradient = LinearGradient(
        colors: [
            Color(red: 0.9, green: 0.6, blue: 0.7),    // Pink
            Color(red: 0.7, green: 0.65, blue: 0.85),  // Purple
            Color(red: 0.45, green: 0.55, blue: 0.85)  // Blue
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Bottom line
                WavyLine(
                    startPoint: CGPoint(x: -20, y: geo.size.height - 30),
                    endPoint: CGPoint(x: geo.size.width + 20, y: geo.size.height - 100),
                    waveHeight: 20,
                    frequency: 1.5
                )
                .stroke(gradient, lineWidth: 2.5)

                // Middle line
                WavyLine(
                    startPoint: CGPoint(x: -20, y: geo.size.height - 60),
                    endPoint: CGPoint(x: geo.size.width + 20, y: geo.size.height - 140),
                    waveHeight: 18,
                    frequency: 1.8
                )
                .stroke(gradient, lineWidth: 2.5)

                // Top line
                WavyLine(
                    startPoint: CGPoint(x: -20, y: geo.size.height - 90),
                    endPoint: CGPoint(x: geo.size.width + 20, y: geo.size.height - 170),
                    waveHeight: 22,
                    frequency: 1.3
                )
                .stroke(gradient, lineWidth: 2.5)
            }
        }
    }
}

// Custom wavy line shape
struct WavyLine: Shape {
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

// MARK: - Gradient Arrow Button

struct GradientArrowButton: View {
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
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
                    .frame(width: 70, height: 70)
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

#Preview {
    AuthFlowView { isNewUser in
        print("Auth complete, isNewUser: \(isNewUser)")
    }
}
