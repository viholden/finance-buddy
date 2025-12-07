import SwiftUI

struct EnhancedGoalsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var goalsManager = GoalsManager()
    @State private var showingAddGoal = false
    @State private var editingGoal: Goal?
    
    var totalSaved: Double {
        goalsManager.goals.reduce(0) { $0 + $1.currentAmount }
    }
    
    var totalTarget: Double {
        goalsManager.goals.reduce(0) { $0 + $1.targetAmount }
    }
    
    var overallProgress: Double {
        guard totalTarget > 0 else { return 0 }
        return min(totalSaved / totalTarget, 1.0)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Saved")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("$\(totalSaved.isFinite ? Int(totalSaved) : 0)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Goal Target")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("$\(totalTarget.isFinite ? Int(totalTarget) : 0)")
                                .font(.system(size: 32, weight: .bold))
                        }
                    }
                    
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.15, green: 0.65, blue: 0.45), Color(red: 0.25, green: 0.75, blue: 0.55)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: (UIScreen.main.bounds.width - 64) * CGFloat(overallProgress), height: 12)
                    }
                    
                    Text("\(overallProgress.isFinite ? Int(overallProgress * 100) : 0)% of your total goals completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                
                // Goals List
                if goalsManager.goals.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "target")
                            .font(.system(size: 60))
                            .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.5))
                        Text("No goals yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Tap + to create your first savings goal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(goalsManager.goals) { goal in
                        Button(action: { editingGoal = goal }) {
                            EnhancedGoalCard(goal: goal)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Savings Goals")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddGoal = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                }
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalView(goalsManager: goalsManager)
        }
        .sheet(item: $editingGoal) { goal in
            if let uid = authManager.userId {
                EditGoalProgressSheet(uid: uid, goal: goal, goalsManager: goalsManager)
            } else {
                Text("Sign in to edit goals")
                    .padding()
            }
        }
        .task {
            if let userId = authManager.userId {
                try? await goalsManager.fetchGoals(uid: userId)
            }
        }
    }
}

struct EnhancedGoalCard: View {
    let goal: Goal
    
    var progress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return min(goal.currentAmount / goal.targetAmount, 1.0)
    }
    
    var category: String {
        // Infer category from goal name
        if goal.name.contains("Emergency") || goal.name.contains("Fund") {
            return "Savings"
        } else if goal.name.contains("Vacation") || goal.name.contains("Trip") || goal.name.contains("Hawaii") {
            return "Travel"
        } else if goal.name.contains("MacBook") || goal.name.contains("Laptop") || goal.name.contains("Tech") {
            return "Tech"
        } else if goal.name.contains("Loan") || goal.name.contains("Debt") {
            return "Debt"
        }
        return "Savings"
    }
    
    var categoryIcon: String {
        switch category {
        case "Travel": return "airplane"
        case "Tech": return "laptopcomputer"
        case "Debt": return "creditcard.fill"
        default: return "banknote.fill"
        }
    }
    
    var categoryColor: Color {
        switch category {
        case "Travel": return Color(red: 0.3, green: 0.8, blue: 0.6)
        case "Tech": return Color(red: 0.25, green: 0.75, blue: 0.55)
        case "Debt": return Color(red: 0.35, green: 0.85, blue: 0.65)
        default: return Color(red: 0.2, green: 0.7, blue: 0.5)
        }
    }
    
    var daysRemaining: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: goal.deadline).day ?? 0
        return "\(days) days left"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: categoryIcon)
                        .font(.title3)
                        .foregroundColor(categoryColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(progress.isFinite ? Int(progress * 100) : 0)%")
                        .font(.headline)
                        .foregroundColor(categoryColor)
                    Text("$\(goal.currentAmount.isFinite ? Int(goal.currentAmount) : 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(categoryColor)
                    .frame(width: CGFloat(progress) * (UIScreen.main.bounds.width - 64), height: 8)
            }
            
            HStack {
                Label(daysRemaining, systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("$\(max(0, goal.targetAmount - goal.currentAmount).isFinite ? Int(max(0, goal.targetAmount - goal.currentAmount)) : 0) to go")
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

struct EditGoalProgressSheet: View, Identifiable {
    let id = UUID()
    let uid: String
    @ObservedObject var goalsManager: GoalsManager
    @Environment(\.dismiss) private var dismiss
    @State private var goal: Goal
    @State private var amountText: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    init(uid: String, goal: Goal, goalsManager: GoalsManager) {
        self.uid = uid
        self._goal = State(initialValue: goal)
        self._amountText = State(initialValue: String(format: "%.2f", goal.currentAmount))
        self._goalsManager = ObservedObject(wrappedValue: goalsManager)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Update Savings") {
                    TextField("Amount saved", text: $amountText)
                        .keyboardType(.decimalPad)
                }
                Section("Details") {
                    HStack {
                        Text("Goal")
                        Spacer()
                        Text(goal.name)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Target")
                        Spacer()
                        Text("$\(goal.targetAmount, specifier: "%.2f")")
                            .foregroundColor(.secondary)
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Update Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveGoal() }
                        .disabled(isSaving)
                }
            }
        }
    }
    
    private func saveGoal() {
        guard let amount = Double(amountText) else {
            errorMessage = "Enter a valid number"
            return
        }
        isSaving = true
        Task {
            do {
                goal.currentAmount = max(0, amount)
                let progress = goal.targetAmount > 0 ? min(goal.currentAmount / goal.targetAmount, 1.0) : 0
                goal.progressPercent = progress
                try await goalsManager.updateGoal(uid: uid, goal: goal)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
