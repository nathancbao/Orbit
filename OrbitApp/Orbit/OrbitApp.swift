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
