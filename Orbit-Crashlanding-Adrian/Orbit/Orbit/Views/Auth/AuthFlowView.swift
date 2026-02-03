//
//  AuthFlowView.swift
//  Orbit
//
//  Email verification flow for .edu emails.
//  Use code "123456" for demo bypass.
//

import SwiftUI

struct AuthFlowView: View {
    @StateObject private var viewModel = AuthViewModel()
    let onAuthComplete: (Bool) -> Void // passes isNewUser

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("Orbit")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    Text("Find your crew")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Auth form
                VStack(spacing: 20) {
                    switch viewModel.authState {
                    case .emailEntry:
                        emailEntrySection
                    case .verification:
                        verificationSection
                    case .authenticated:
                        // Briefly show success then callback
                        ProgressView()
                            .tint(.white)
                            .onAppear {
                                onAuthComplete(viewModel.isNewUser)
                            }
                    }

                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Demo hint
                Text("Demo: Use code 123456")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom)
            }
        }
    }

    // MARK: - Email Entry

    private var emailEntrySection: some View {
        VStack(spacing: 16) {
            Text("Enter your .edu email")
                .font(.headline)
                .foregroundColor(.white)

            TextField("you@university.edu", text: $viewModel.email)
                .textFieldStyle(.plain)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .foregroundColor(.white)

            Button(action: {
                Task {
                    await viewModel.sendVerificationCode()
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Send Code")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(viewModel.isEmailValid ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(!viewModel.isEmailValid || viewModel.isLoading)
        }
    }

    // MARK: - Verification

    private var verificationSection: some View {
        VStack(spacing: 16) {
            Text("Enter verification code")
                .font(.headline)
                .foregroundColor(.white)

            Text("Sent to \(viewModel.email)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            TextField("123456", text: $viewModel.verificationCode)
                .textFieldStyle(.plain)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .foregroundColor(.white)

            Button(action: {
                Task {
                    await viewModel.verifyCode()
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Verify")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(viewModel.isCodeValid ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(!viewModel.isCodeValid || viewModel.isLoading)

            Button("Use different email") {
                viewModel.resetToEmailEntry()
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))
        }
    }
}

#Preview {
    AuthFlowView { isNewUser in
        print("Auth complete, isNewUser: \(isNewUser)")
    }
}
