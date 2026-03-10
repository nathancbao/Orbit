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
    @State private var deepLinkFriendId: Int?

    var body: some Scene {
        WindowGroup {
            ContentView(deepLinkFriendId: $deepLinkFriendId)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Expected format: https://orbit-app-486204.wl.r.appspot.com/friend/{user_id}
        let path = url.pathComponents  // e.g. ["/", "friend", "123"]
        guard path.count >= 3,
              path[1] == "friend",
              let userId = Int(path[2]) else { return }
        deepLinkFriendId = userId
    }
}

// MARK: - Lock orientation to portrait

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}
