import SwiftUI

struct EditQuestionnaireView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @Environment(\.dismiss) var dismiss
    
    @State private var financialGoal: String
    @State private var incomeRange: String
    @State private var expenses: [String]
    @State private var riskTolerance: String
    @State private var savingsExperience: String
    @State private var primaryConcerns: [String]
    @State private var additionalComments: String
    @State private var isSaving = false
    @State private var showingHistory = false
    
    init(currentResponse: QuestionnaireResponse?) {
        _financialGoal = State(initialValue: currentResponse?.financialGoal ?? "")
        _incomeRange = State(initialValue: currentResponse?.incomeRange ?? "")
        _expenses = State(initialValue: currentResponse?.expenses ?? [])
        _riskTolerance = State(initialValue: currentResponse?.riskTolerance ?? "")
        _savingsExperience = State(initialValue: currentResponse?.savingsExperience ?? "")
        _primaryConcerns = State(initialValue: currentResponse?.primaryConcerns ?? [])
        _additionalComments = State(initialValue: currentResponse?.additionalComments ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Financial Goal")) {
                    Picker("Primary Goal", selection: $financialGoal) {
                        Text("Select...").tag("")
                        ForEach(QuestionnaireManager.questions[0].options ?? [], id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
                
                Section(header: Text("Income Range")) {
                    Picker("Annual Income", selection: $incomeRange) {
                        Text("Select...").tag("")
                        ForEach(QuestionnaireManager.questions[1].options ?? [], id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
                
                Section(header: Text("Major Expenses")) {
                    ForEach(QuestionnaireManager.questions[2].options ?? [], id: \.self) { option in
                        Toggle(option, isOn: Binding(
                            get: { expenses.contains(option) },
                            set: { isSelected in
                                if isSelected {
                                    expenses.append(option)
                                } else {
                                    expenses.removeAll { $0 == option }
                                }
                            }
                        ))
                    }
                }
                
                Section(header: Text("Risk Tolerance")) {
                    Picker("Risk Level", selection: $riskTolerance) {
                        Text("Select...").tag("")
                        ForEach(QuestionnaireManager.questions[3].options ?? [], id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
                
                Section(header: Text("Savings Experience")) {
                    Picker("Experience Level", selection: $savingsExperience) {
                        Text("Select...").tag("")
                        ForEach(QuestionnaireManager.questions[4].options ?? [], id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
                
                Section(header: Text("Primary Concerns")) {
                    ForEach(QuestionnaireManager.questions[5].options ?? [], id: \.self) { option in
                        Toggle(option, isOn: Binding(
                            get: { primaryConcerns.contains(option) },
                            set: { isSelected in
                                if isSelected {
                                    primaryConcerns.append(option)
                                } else {
                                    primaryConcerns.removeAll { $0 == option }
                                }
                            }
                        ))
                    }
                }
                
                Section(header: Text("Tell me anything!")) {
                    TextEditor(text: $additionalComments)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Button(action: { showingHistory = true }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("View Update History")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Update Questionnaire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving)
                }
            }
            .sheet(isPresented: $showingHistory) {
                QuestionnaireHistoryView()
            }
        }
    }
    
    private func saveChanges() {
        guard let uid = authManager.user?.uid else { return }
        isSaving = true
        
        let updatedResponse = QuestionnaireResponse(
            financialGoal: financialGoal.isEmpty ? nil : financialGoal,
            incomeRange: incomeRange.isEmpty ? nil : incomeRange,
            expenses: expenses.isEmpty ? nil : expenses,
            riskTolerance: riskTolerance.isEmpty ? nil : riskTolerance,
            savingsExperience: savingsExperience.isEmpty ? nil : savingsExperience,
            primaryConcerns: primaryConcerns.isEmpty ? nil : primaryConcerns,
            additionalComments: additionalComments.isEmpty ? nil : additionalComments,
            updatedAt: Date()
        )
        
        Task {
            try? await firestoreManager.updateQuestionnaireResponses(uid: uid, responses: updatedResponse)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

struct QuestionnaireHistoryView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @State private var history: [QuestionnaireHistoryEntry] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else if history.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No History Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Updates to your questionnaire will appear here")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(history) { entry in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(entry.timestamp, style: .date)
                                        .font(.headline)
                                    Spacer()
                                    Text(entry.timestamp, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let goal = entry.financialGoal {
                                    InfoRow(label: "Financial Goal", value: goal)
                                }
                                if let income = entry.incomeRange {
                                    InfoRow(label: "Income Range", value: income)
                                }
                                if let expenses = entry.expenses, !expenses.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Expenses:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(expenses.joined(separator: ", "))
                                            .font(.subheadline)
                                    }
                                }
                                if let risk = entry.riskTolerance {
                                    InfoRow(label: "Risk Tolerance", value: risk)
                                }
                                if let experience = entry.savingsExperience {
                                    InfoRow(label: "Experience", value: experience)
                                }
                                if let concerns = entry.primaryConcerns, !concerns.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Concerns:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(concerns.joined(separator: ", "))
                                            .font(.subheadline)
                                    }
                                }
                                if let comments = entry.additionalComments, !comments.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Additional Comments:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(comments)
                                            .font(.subheadline)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Update History")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadHistory()
        }
    }
    
    private func loadHistory() async {
        guard let uid = authManager.user?.uid else { return }
        
        do {
            let entries = try await firestoreManager.fetchQuestionnaireHistory(uid: uid)
            await MainActor.run {
                self.history = entries
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }
}

#Preview {
    EditQuestionnaireView(currentResponse: nil)
        .environmentObject(AuthenticationManager())
        .environmentObject(FirestoreManager())
}
