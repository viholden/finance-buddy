//
//  finance_buddyApp.swift
//  finance buddy
//
//  Created by Hannah Holden on 10/1/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase if GoogleService-Info.plist exists
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           FileManager.default.fileExists(atPath: path) {
            FirebaseApp.configure()
            print("✅ Firebase configured successfully")
        } else {
            print("⚠️ GoogleService-Info.plist not found. Firebase features will be disabled.")
            print("   To enable Firebase:")
            print("   1. Download GoogleService-Info.plist from Firebase Console")
            print("   2. Add it to your Xcode project in the 'finance buddy' folder")
            print("   3. Ensure it's added to the app target")
        }
        return true
    }
}

@main
struct finance_buddyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager: AuthenticationManager
    @StateObject private var firestoreManager = FirestoreManager()
    @AppStorage("isDarkMode") private var isDarkMode = false

    init() {
        // Ensure Firebase is configured before creating objects that use it.
        if FirebaseApp.app() == nil {
            if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
               FileManager.default.fileExists(atPath: path) {
                FirebaseApp.configure()
                print("✅ Firebase configured in App init")
            } else {
                print("⚠️ GoogleService-Info.plist not found. Firebase features will be disabled.")
            }
        }

        _authManager = StateObject(wrappedValue: AuthenticationManager())
    }
    
    var body: some Scene {
        WindowGroup {
            if authManager.user != nil {
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(firestoreManager)
                    .preferredColorScheme(isDarkMode ? .dark : .light)
                    .task {
                        if let uid = authManager.user?.uid {
                            try? await firestoreManager.fetchUserProfile(uid: uid)
                            if let darkMode = firestoreManager.userProfile?.darkMode {
                                isDarkMode = darkMode
                            }
                        }
                    }
            } else {
                AuthenticationView()
                    .environmentObject(authManager)
                    .environmentObject(firestoreManager)
            }
        }
    }
}
