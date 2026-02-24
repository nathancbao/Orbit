import Foundation
import Combine
import SwiftUI

// ProfileViewModel is now a thin wrapper — the actual form state lives
// directly in QuickProfileSetupView. This file is kept for any shared
// profile state needed across the app (e.g. refreshing profile data).

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadProfile() async {
        isLoading = true
        do {
            profile = try await ProfileService.shared.getProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
