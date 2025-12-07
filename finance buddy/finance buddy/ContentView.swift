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
                    Label("Home", systemImage: "house.fill")
                }
            
            NavigationView {
                AIAdvisorChatView()
            }
            .tabItem {
                Label("AI Advisor", systemImage: "message.fill")
            }
            
            NavigationView {
                EnhancedGoalsView()
            }
            .tabItem {
                Label("Goals", systemImage: "target")
            }
            
            NavigationView {
                EnhancedExpensesView()
            }
            .tabItem {
                Label("Expenses", systemImage: "creditcard.fill")
            }
            
            NavigationView {
                EnhancedLessonsView()
            }
            .tabItem {
                Label("Learn", systemImage: "book.fill")
            }
        }
        .accentColor(Color(red: 0.2, green: 0.7, blue: 0.5))
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
    @StateObject private var expensesManager = ExpensesManager()
    @StateObject private var goalsManager = GoalsManager()
    @StateObject private var bankingManager = BankingManager()
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showingProfile = false
    @State private var showingNotifications = false
    @State private var showingAddExpense = false
    @State private var showingAddGoal = false
    @State private var showingStats = false
    @State private var showingAIAdvisor = false
    
    var totalExpenses: Double {
        expensesManager.expenses.reduce(0) { $0 + $1.amount }
    }
    
    var totalIncome: Double {
        let calendar = Calendar.current
        return bankingManager.transactions
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }
    
    var totalBalance: Double {
        totalIncome - totalExpenses
    }
    
    var recentExpenses: [Expense] {
        Array(expensesManager.expenses.sorted { $0.date > $1.date }.prefix(4))
    }
    
    var recentGoals: [Goal] {
        let sortedGoals = goalsManager.goals.sorted { goal1, goal2 in
            let progress1 = goal1.targetAmount > 0 ? goal1.currentAmount / goal1.targetAmount : 0
            let progress2 = goal2.targetAmount > 0 ? goal2.currentAmount / goal2.targetAmount : 0
            return progress1 > progress2
        }
        return Array(sortedGoals.prefix(3))
    }
    
    func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "food", "groceries": return "cart.fill"
        case "coffee": return "cup.and.saucer.fill"
        case "dining", "restaurant": return "fork.knife"
        case "transport", "transportation": return "car.fill"
        case "bills", "utilities": return "bolt.fill"
        case "entertainment": return "tv.fill"
        case "shopping": return "bag.fill"
        default: return "dollarsign.circle.fill"
        }
    }
    
    var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Good Morning,")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(firestoreManager.userProfile?.name ?? "User")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            Button(action: { showingProfile = true }) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
            }
        }
        .padding(.horizontal)
    }
    
    var balanceCardView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [Color(red: 0.15, green: 0.65, blue: 0.45), Color(red: 0.25, green: 0.75, blue: 0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Balance")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        Text("$\(totalBalance, specifier: "%.2f")")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.3))
                }
                
                HStack(spacing: 16) {
                    BalanceCard(title: "Income", amount: String(format: "$%.2f", totalIncome), icon: "arrow.down.circle.fill", color: .white.opacity(0.9))
                    BalanceCard(title: "Expenses", amount: String(format: "$%.2f", totalExpenses), icon: "arrow.up.circle.fill", color: .white.opacity(0.9))
                }
            }
            .padding(24)
        }
        .frame(height: 200)
        .padding(.horizontal)
    }
    
    var quickActionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    QuickActionCard(icon: "plus.circle.fill", title: "Add Expense", color: Color(red: 0.3, green: 0.8, blue: 0.6)) {
                        showingAddExpense = true
                    }
                    QuickActionCard(icon: "target", title: "New Goal", color: Color(red: 0.2, green: 0.7, blue: 0.5)) {
                        showingAddGoal = true
                    }
                    QuickActionCard(icon: "chart.line.uptrend.xyaxis", title: "View Stats", color: Color(red: 0.4, green: 0.85, blue: 0.65)) {
                        showingStats = true
                    }
                    QuickActionCard(icon: "message.fill", title: "Ask AI", color: Color(red: 0.25, green: 0.75, blue: 0.55)) {
                        showingAIAdvisor = true
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    var recentActivityView: some View {
        if !recentExpenses.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Activity")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    ForEach(recentExpenses) { expense in
                        ActivityCard(
                            icon: categoryIcon(for: expense.category),
                            title: expense.merchant.isEmpty ? expense.description : expense.merchant,
                            category: expense.category,
                            amount: String(format: "-$%.2f", expense.amount),
                            color: Color(red: 0.2, green: 0.7, blue: 0.5),
                            isPositive: false
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    var savingsGoalsView: some View {
        if !recentGoals.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Savings Goals")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    ForEach(recentGoals) { goal in
                        GoalProgressCard(
                            title: goal.name,
                            current: goal.currentAmount,
                            target: goal.targetAmount,
                            color: Color(red: 0.2, green: 0.7, blue: 0.5)
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    balanceCardView
                    quickActionsView
                    recentActivityView
                    savingsGoalsView
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNotifications = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.title3)
                                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                            
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
            .sheet(isPresented: $showingAddExpense) {
                NavigationView {
                    AddExpenseView(expensesManager: expensesManager)
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddGoalView(goalsManager: goalsManager)
            }
            .sheet(isPresented: $showingStats) {
                NavigationView {
                    DashboardStatsSheet(
                        totalBalance: totalBalance,
                        totalIncome: totalIncome,
                        totalExpenses: totalExpenses,
                        goals: goalsManager.goals
                    )
                }
            }
            .sheet(isPresented: $showingAIAdvisor) {
                NavigationView {
                    AIAdvisorChatView()
                }
            }
            .task {
                if let userId = authManager.userId {
                    if firestoreManager.userProfile == nil {
                        try? await firestoreManager.fetchUserProfile(uid: userId)
                    }
                    try? await expensesManager.fetchExpenses(uid: userId)
                    try? await goalsManager.fetchGoals(uid: userId)
                    await bankingManager.fetchBankingData(uid: userId)
                }
            }
        }
    }
}

struct BalanceCard: View {
    let title: String
    let amount: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                Text(amount)
                    .font(.headline)
            }
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(width: 100)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct DashboardStatsSheet: View {
    let totalBalance: Double
    let totalIncome: Double
    let totalExpenses: Double
    let goals: [Goal]
    
    var body: some View {
        List {
            Section("Cash Flow") {
                statRow(title: "Monthly Income", value: totalIncome)
                statRow(title: "Monthly Expenses", value: totalExpenses)
                statRow(title: "Income - Expenses", value: totalBalance)
            }
            
            if !goals.isEmpty {
                Section("Goals Snapshot") {
                    ForEach(goals.prefix(5)) { goal in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(goal.name)
                                .font(.headline)
                            Text("$\(Int(goal.currentAmount)) / $\(Int(goal.targetAmount))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Financial Stats")
    }
    
    private func statRow(title: String, value: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("$\(value, specifier: "%.2f")")
                .fontWeight(.semibold)
        }
    }
}

struct ActivityCard: View {
    let icon: String
    let title: String
    let category: String
    let amount: String
    let color: Color
    let isPositive: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(amount)
                .font(.headline)
                .foregroundColor(isPositive ? Color(red: 0.2, green: 0.7, blue: 0.5) : .primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct GoalProgressCard: View {
    let title: String
    let current: Double
    let target: Double
    let color: Color
    
    var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }
    
    var progressPercentage: Int {
        Int((progress * 100).rounded())
    }
    
    var progressWidth: CGFloat {
        let maxWidth = UIScreen.main.bounds.width - 64
        return max(0, min(CGFloat(progress) * maxWidth, maxWidth))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(progressPercentage)%")
                    .font(.subheadline)
                    .foregroundColor(color)
            }
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.2))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: progressWidth, height: 8)
            }
            
            HStack {
                Text("$\(current.isFinite ? Int(current) : 0)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("$\(target.isFinite ? Int(target) : 0)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
        .environmentObject(FirestoreManager())
}
