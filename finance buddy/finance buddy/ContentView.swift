//
//  ContentView.swift
//  finance buddy
//
//  Created by Hannah Holden on 10/1/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @StateObject private var notificationsManager = NotificationsManager()
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
            
            NavigationView {
                GoalsView()
            }
            .tabItem {
                Label("Goals", systemImage: "target")
            }
            
            NavigationView {
                ExpensesView()
            }
            .tabItem {
                Label("Expenses", systemImage: "creditcard.fill")
            }
            
            NavigationView {
                LessonsView()
            }
            .tabItem {
                Label("Learn", systemImage: "book.fill")
            }
            
            NavigationView {
                ChallengesView()
            }
            .tabItem {
                Label("Challenges", systemImage: "trophy.fill")
            }
        }
        .environmentObject(notificationsManager)
        .task {
            if let uid = authManager.user?.uid {
                try? await notificationsManager.fetchNotifications(uid: uid)
            }
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @EnvironmentObject var notificationsManager: NotificationsManager
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showingProfile = false
    @State private var showingNotifications = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let profile = firestoreManager.userProfile {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Welcome back,")
                                        .foregroundColor(.secondary)
                                    Text(profile.name)
                                        .font(.title)
                                        .fontWeight(.bold)
                                }
                                
                                Spacer()
                                
                                Button(action: { showingProfile = true }) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            HStack(spacing: 20) {
                                VStack {
                                    HStack {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                        Text("\(profile.totalPoints)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                    }
                                    Text("Total Points")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                                
                                VStack {
                                    HStack {
                                        Image(systemName: "dollarsign.circle.fill")
                                            .foregroundColor(.green)
                                        Text(profile.currency)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                    }
                                    Text("Currency")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                    } else if firestoreManager.isLoading {
                        ProgressView()
                            .padding()
                    }
                    
                    QuickActionsView()
                    
                    RecentActivityView()
                }
                .padding()
            }
            .navigationTitle("Finance Buddy")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNotifications = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.title3)
                            
                            if notificationsManager.unreadCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                NavigationView {
                    ProfileView()
                }
            }
            .sheet(isPresented: $showingNotifications) {
                NavigationView {
                    NotificationsView()
                }
            }
        }
    }
}

struct QuickActionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            HStack(spacing: 12) {
                NavigationLink(destination: GoalsView()) {
                    QuickActionButton(icon: "target", title: "Goals", color: .blue)
                }
                
                NavigationLink(destination: ExpensesView()) {
                    QuickActionButton(icon: "creditcard", title: "Expenses", color: .red)
                }
                
                NavigationLink(destination: LessonsView()) {
                    QuickActionButton(icon: "book", title: "Learn", color: .green)
                }
                
                NavigationLink(destination: ChallengesView()) {
                    QuickActionButton(icon: "trophy", title: "Challenge", color: .orange)
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct RecentActivityView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            
            VStack(spacing: 8) {
                ActivityRow(icon: "checkmark.circle.fill", text: "Completed Budget Basics", color: .green)
                ActivityRow(icon: "plus.circle.fill", text: "Added new expense: Coffee", color: .blue)
                ActivityRow(icon: "target", text: "Updated goal: Save for laptop", color: .orange)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct ActivityRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.subheadline)
            Spacer()
            Text("Today")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
        .environmentObject(FirestoreManager())
}
