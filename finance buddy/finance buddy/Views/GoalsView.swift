import SwiftUI

struct GoalsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var goalsManager = GoalsManager()
    @State private var showingAddGoal = false
    
    var body: some View {
        ZStack {
            if goalsManager.isLoading {
                ProgressView()
            } else if goalsManager.goals.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "target")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No Goals Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Start by adding your first savings goal")
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(goalsManager.goals) { goal in
                        NavigationLink(destination: GoalDetailView(goalsManager: goalsManager, goal: goal)) {
                            GoalRowView(goal: goal)
                        }
                    }
                    .onDelete { indexSet in
                        deleteGoals(at: indexSet)
                    }
                }
            }
        }
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddGoal = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalView(goalsManager: goalsManager)
        }
        .task {
            if let uid = authManager.user?.uid {
                try? await goalsManager.fetchGoals(uid: uid)
            }
        }
    }
    
    private func deleteGoals(at offsets: IndexSet) {
        guard let uid = authManager.user?.uid else { return }
        
        for index in offsets {
            let goal = goalsManager.goals[index]
            Task {
                try? await goalsManager.deleteGoal(uid: uid, goalId: goal.id)
            }
        }
    }
}

struct GoalRowView: View {
    let goal: Goal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.name)
                    .font(.headline)
                Spacer()
                if goal.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            ProgressView(value: goal.progressPercent, total: 100)
                .tint(goal.isCompleted ? .green : .blue)
            
            HStack {
                Text("$\(goal.currentAmount, specifier: "%.2f") / $\(goal.targetAmount, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(goal.deadline, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddGoalView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var goalsManager: GoalsManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var targetAmount = ""
    @State private var currentAmount = ""
    @State private var deadline = Date().addingTimeInterval(86400 * 30)
    @State private var remindersEnabled = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Goal Details")) {
                    TextField("Goal Name", text: $name)
                    TextField("Target Amount", text: $targetAmount)
                        .keyboardType(.decimalPad)
                    TextField("Current Amount", text: $currentAmount)
                        .keyboardType(.decimalPad)
                    DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                }
                
                Section {
                    Toggle("Enable Reminders", isOn: $remindersEnabled)
                }
            }
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGoal()
                    }
                    .disabled(name.isEmpty || targetAmount.isEmpty)
                }
            }
        }
    }
    
    private func saveGoal() {
        guard let uid = authManager.user?.uid,
              let target = Double(targetAmount) else { return }
        
        let current = Double(currentAmount) ?? 0
        let progress = target > 0 ? (current / target) * 100 : 0
        
        let goal = Goal(
            name: name,
            targetAmount: target,
            currentAmount: current,
            deadline: deadline,
            progressPercent: progress,
            remindersEnabled: remindersEnabled
        )
        
        Task {
            try? await goalsManager.addGoal(uid: uid, goal: goal)
            await MainActor.run { dismiss() }
        }
    }
}

struct GoalDetailView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var goalsManager: GoalsManager
    @State var goal: Goal
    @State private var isEditing = false
    @State private var newAmount = ""
    
    var body: some View {
        Form {
            Section(header: Text("Progress")) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 20)
                            .frame(width: 150, height: 150)
                        
                        Circle()
                            .trim(from: 0, to: goal.progressPercent / 100)
                            .stroke(goal.isCompleted ? Color.green : Color.blue, lineWidth: 20)
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(goal.progressPercent))%")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    
                    Text("$\(goal.currentAmount, specifier: "%.2f") of $\(goal.targetAmount, specifier: "%.2f")")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            
            Section(header: Text("Details")) {
                HStack {
                    Text("Goal Name")
                    Spacer()
                    Text(goal.name)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Deadline")
                    Spacer()
                    Text(goal.deadline, style: .date)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Remaining")
                    Spacer()
                    Text("$\(goal.targetAmount - goal.currentAmount, specifier: "%.2f")")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Update Progress")) {
                HStack {
                    TextField("Add Amount", text: $newAmount)
                        .keyboardType(.decimalPad)
                    
                    Button("Add") {
                        updateProgress()
                    }
                    .disabled(newAmount.isEmpty)
                }
            }
        }
        .navigationTitle("Goal Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func updateProgress() {
        guard let uid = authManager.user?.uid,
              let amount = Double(newAmount) else { return }
        
        goal.currentAmount += amount
        goal.progressPercent = goal.targetAmount > 0 ? (goal.currentAmount / goal.targetAmount) * 100 : 0
        
        Task {
            try? await goalsManager.updateGoal(uid: uid, goal: goal)
            await MainActor.run { newAmount = "" }
        }
    }
}
