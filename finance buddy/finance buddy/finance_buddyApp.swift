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
        FirebaseApp.configure()
        return true
    }
}

@main
struct finance_buddyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var firestoreManager = FirestoreManager()
    @AppStorage("isDarkMode") private var isDarkMode = false
    
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
