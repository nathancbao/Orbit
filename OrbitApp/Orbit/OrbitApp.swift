//
//  OrbitApp.swift
//  Orbit
//
//  Created by Adrian Nguyen on 2/1/26.
//

import SwiftUI

@main
struct OrbitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var deepLinkFriendId: Int?

    var body: some Scene {
        WindowGroup {
            ContentView(deepLinkFriendId: $deepLinkFriendId)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // New foreground session — start a session id, record the open,
                // and flush anything held from before.
                AnalyticsService.shared.startSession()
                AnalyticsService.shared.track(.appOpened)
            case .background:
                // Best chance to ship buffered events before we're suspended.
                Task { await AnalyticsService.shared.flush() }
            default:
                break
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Universal link: https://orbit-app-486204.wl.r.appspot.com/friend/{user_id}
        //   → pathComponents = ["/", "friend", "123"]
        // Custom scheme:  orbit://friend/{user_id}
        //   → host = "friend", pathComponents = ["/", "123"]

        if url.scheme == "orbit", url.host == "friend",
           let first = url.pathComponents.dropFirst().first,
           let userId = Int(first) {
            deepLinkFriendId = userId
        } else if url.pathComponents.count >= 3,
                  url.pathComponents[1] == "friend",
                  let userId = Int(url.pathComponents[2]) {
            deepLinkFriendId = userId
        }
    }
}

// MARK: - Lock orientation to portrait

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}
