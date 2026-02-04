// ContentView.swift
// Main content view with authentication flow.

import SwiftUI

// MARK: - Color Theme
extension Color {
    static let orbitPeach = Color(red: 1.0, green: 0.54, blue: 0.50)      // #ff8a80
    static let orbitLilac = Color(red: 0.70, green: 0.53, blue: 1.0)      // #b288ff
}

// MARK: - Authentication View Model
class AuthViewModel: ObservableObject {
    var authService = AuthenticationService()

    @Published var email: String = ""
    @Published var password: String = ""
    @Published var verificationCode: String = ""
    @Published var confirmPassword: String = ""

    @Published var currentScreen: AuthScreen = .launch
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var emailSentSuccessfully: Bool = false

    /// Cooldown timer for resend button (seconds remaining)
    @Published var resendCooldown: Int = 0
    private var cooldownTimer: Timer?

    enum AuthScreen {
        case launch
        case emailEntry
        case passwordEntry      // Existing user
        case verificationCode   // New user verification
        case createPassword     // New user password creation
        case authenticated
    }

    // Check if email exists and navigate accordingly
    func submitEmail() {
        errorMessage = nil

        // Validate email
        switch authService.validateEmail(email) {
        case .failure(let error):
            errorMessage = error.localizedDescription
            return
        case .success(_):
            break
        }

        isLoading = true

        // Check if account exists
        if authService.accountExists(email: email) {
            // Existing user - go to password
            currentScreen = .passwordEntry
            isLoading = false
        } else {
            // New user - send verification code via email
            sendVerificationEmail()
        }
    }

    /// Sends verification email asynchronously
    func sendVerificationEmail() {
        isLoading = true
        errorMessage = nil
        emailSentSuccessfully = false

        Task { @MainActor in
            let result = await authService.sendVerificationCodeAsync(to: email)

            switch result {
            case .success(_):
                emailSentSuccessfully = true
                currentScreen = .verificationCode
                startResendCooldown()
            case .failure(let error):
                // Check if it's a configuration error
                if error.localizedDescription.contains("not configured") {
                    // Fall back to local-only mode for testing without email
                    let localResult = authService.sendVerificationCode(to: email)
                    switch localResult {
                    case .success(_):
                        errorMessage = "Email service not configured. Using test mode - check console for code."
                        currentScreen = .verificationCode
                    case .failure(let localError):
                        errorMessage = localError.localizedDescription
                    }
                } else {
                    errorMessage = error.localizedDescription
                }
            }

            isLoading = false
        }
    }

    /// Resend verification code
    func resendVerificationCode() {
        guard resendCooldown == 0 else { return }
        sendVerificationEmail()
    }

    /// Start cooldown timer for resend button
    private func startResendCooldown() {
        resendCooldown = 60 // 60 second cooldown

        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                if self.resendCooldown > 0 {
                    self.resendCooldown -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }

    // Verify the code for new users
    func submitVerificationCode() {
        errorMessage = nil
        isLoading = true

        let result = authService.verifyCode(verificationCode, for: email)
        switch result {
        case .success(_):
            currentScreen = .createPassword
        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // Create account for new users
    func createAccount() {
        errorMessage = nil

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        isLoading = true

        let result = authService.createAccount(email: email, password: password)
        switch result {
        case .success(_):
            // Auto-login after account creation
            let loginResult = authService.login(email: email, password: password)
            switch loginResult {
            case .success(_):
                currentScreen = .authenticated
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // Login for existing users
    func login() {
        errorMessage = nil
        isLoading = true

        let result = authService.login(email: email, password: password)
        switch result {
        case .success(_):
            currentScreen = .authenticated
        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // Logout
    func logout() {
        authService.logout()
        email = ""
        password = ""
        verificationCode = ""
        confirmPassword = ""
        errorMessage = nil
        emailSentSuccessfully = false
        currentScreen = .launch
    }

    // Go back
    func goBack() {
        errorMessage = nil
        switch currentScreen {
        case .emailEntry:
            currentScreen = .launch
        case .passwordEntry, .verificationCode:
            currentScreen = .emailEntry
        case .createPassword:
            currentScreen = .verificationCode
        default:
            break
        }
    }

    deinit {
        cooldownTimer?.invalidate()
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        ZStack {
            // Background gradient wave effect
            WaveBackground()

            // Content based on current screen
            switch viewModel.currentScreen {
            case .launch:
                LaunchScreen(viewModel: viewModel)
            case .emailEntry:
                EmailEntryScreen(viewModel: viewModel)
            case .passwordEntry:
                PasswordEntryScreen(viewModel: viewModel)
            case .verificationCode:
                VerificationCodeScreen(viewModel: viewModel)
            case .createPassword:
                CreatePasswordScreen(viewModel: viewModel)
            case .authenticated:
                AuthenticatedScreen(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Wave Background
struct WaveBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white

                // Bottom wave decoration
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height

                    path.move(to: CGPoint(x: 0, y: height * 0.85))
                    path.addCurve(
                        to: CGPoint(x: width, y: height * 0.75),
                        control1: CGPoint(x: width * 0.3, y: height * 0.95),
                        control2: CGPoint(x: width * 0.7, y: height * 0.65)
                    )
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .stroke(
                    LinearGradient(
                        colors: [Color.orbitPeach, Color.orbitLilac],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Launch Screen
struct LaunchScreen: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Logo and title
            VStack(spacing: 16) {
                // Orbit logo placeholder
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.orbitPeach, Color.orbitLilac],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orbitPeach, Color.orbitLilac],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("ORBIT")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .tracking(8)
            }

            Spacer()

            // Launch button
            Button(action: {
                viewModel.currentScreen = .emailEntry
            }) {
                Text("L A U N C H")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.black, lineWidth: 1)
                    )
            }

            Spacer()
                .frame(height: 100)
        }
        .padding()
    }
}

// MARK: - Email Entry Screen
struct EmailEntryScreen: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Illustration
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 80))
                .foregroundColor(Color.orbitLilac)

            // Title
            Text("type in your email!")
                .font(.system(size: 18, weight: .medium))

            // Email input
            VStack(spacing: 8) {
                TextField("email@example.com", text: $viewModel.email)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($isEmailFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orbitLilac, lineWidth: 1)
                    )
                    .frame(maxWidth: 300)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
            }

            Spacer()

            // Navigation buttons
            HStack {
                Button(action: { viewModel.goBack() }) {
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .foregroundColor(Color.orbitPeach)
                }

                Spacer()

                Button(action: { viewModel.submitEmail() }) {
                    ZStack {
                        Circle()
                            .fill(Color.orbitPeach)
                            .frame(width: 56, height: 56)

                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .padding()
        .onAppear {
            isEmailFocused = true
        }
    }
}

// MARK: - Password Entry Screen (Existing User)
struct PasswordEntryScreen: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Illustration
            Image(systemName: "lock.fill")
                .font(.system(size: 80))
                .foregroundColor(Color.orbitLilac)

            // Title
            Text("enter your password")
                .font(.system(size: 18, weight: .medium))

            // Password input
            VStack(spacing: 8) {
                SecureField("password", text: $viewModel.password)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isPasswordFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orbitLilac, lineWidth: 1)
                    )
                    .frame(maxWidth: 300)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            // Navigation buttons
            HStack {
                Button(action: { viewModel.goBack() }) {
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .foregroundColor(Color.orbitPeach)
                }

                Spacer()

                Button(action: { viewModel.login() }) {
                    Circle()
                        .fill(Color.orbitPeach)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "arrow.right")
                                .font(.title2)
                                .foregroundColor(.white)
                        )
                }
                .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .padding()
        .onAppear {
            isPasswordFocused = true
        }
    }
}

// MARK: - Verification Code Screen (New User)
struct VerificationCodeScreen: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Illustration
            Image(systemName: "envelope.badge")
                .font(.system(size: 80))
                .foregroundColor(Color.orbitLilac)

            // Title
            VStack(spacing: 8) {
                Text("check your email!")
                    .font(.system(size: 18, weight: .medium))

                Text("We sent a 6-digit code to")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)

                Text(viewModel.email)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.orbitLilac)

                // Email sent confirmation
                if viewModel.emailSentSuccessfully {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                        Text("Email sent successfully")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                    .padding(.top, 4)
                }
            }

            // Code input
            VStack(spacing: 8) {
                TextField("000000", text: $viewModel.verificationCode)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .focused($isCodeFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orbitLilac, lineWidth: 1)
                    )
                    .frame(maxWidth: 200)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
            }

            // Resend code button
            Button(action: { viewModel.resendVerificationCode() }) {
                if viewModel.resendCooldown > 0 {
                    Text("Resend code in \(viewModel.resendCooldown)s")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                } else if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Resend code")
                        .font(.system(size: 14))
                        .foregroundColor(Color.orbitPeach)
                        .underline()
                }
            }
            .disabled(viewModel.resendCooldown > 0 || viewModel.isLoading)

            Spacer()

            // Navigation buttons
            HStack {
                Button(action: { viewModel.goBack() }) {
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .foregroundColor(Color.orbitPeach)
                }

                Spacer()

                Button(action: { viewModel.submitVerificationCode() }) {
                    Circle()
                        .fill(Color.orbitPeach)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "arrow.right")
                                .font(.title2)
                                .foregroundColor(.white)
                        )
                }
                .disabled(viewModel.isLoading || viewModel.verificationCode.count != 6)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .padding()
        .onAppear {
            isCodeFocused = true
        }
    }
}

// MARK: - Create Password Screen (New User)
struct CreatePasswordScreen: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    enum Field {
        case password, confirm
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Illustration
            Image(systemName: "key.fill")
                .font(.system(size: 80))
                .foregroundColor(Color.orbitLilac)

            // Title
            Text("create your password")
                .font(.system(size: 18, weight: .medium))

            // Password inputs
            VStack(spacing: 16) {
                SecureField("password (8+ characters)", text: $viewModel.password)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($focusedField, equals: .password)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orbitLilac, lineWidth: 1)
                    )
                    .frame(maxWidth: 300)

                SecureField("confirm password", text: $viewModel.confirmPassword)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($focusedField, equals: .confirm)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orbitLilac, lineWidth: 1)
                    )
                    .frame(maxWidth: 300)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            // Navigation buttons
            HStack {
                Button(action: { viewModel.goBack() }) {
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .foregroundColor(Color.orbitPeach)
                }

                Spacer()

                Button(action: { viewModel.createAccount() }) {
                    Circle()
                        .fill(Color.orbitPeach)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.title2)
                                .foregroundColor(.white)
                        )
                }
                .disabled(viewModel.isLoading || viewModel.password.count < 8)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .padding()
        .onAppear {
            focusedField = .password
        }
    }
}

// MARK: - Authenticated Screen
struct AuthenticatedScreen: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success illustration
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.green)

            Text("Welcome to Orbit!")
                .font(.system(size: 24, weight: .bold))

            if let user = viewModel.authService.getCurrentUser() {
                Text("Logged in as: \(user.email)")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }

            Spacer()

            // Logout button
            Button(action: { viewModel.logout() }) {
                Text("Logout")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Color.orbitPeach)
                    .cornerRadius(25)
            }
            .padding(.bottom, 60)
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
