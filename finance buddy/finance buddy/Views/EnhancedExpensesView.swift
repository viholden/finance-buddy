import SwiftUI

struct EnhancedExpensesView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var expensesManager = ExpensesManager()
    @StateObject private var bankingManager = BankingManager()
    @State private var showingAddExpense = false
    @State private var showingAddDeposit = false
    @State private var showingUpdateBalance = false
    @State private var selectedCategory: String = "All"
    
    let categories = ["All", "Food", "Transportation", "Entertainment", "Shopping", "Bills", "Other"]
    
    var filteredExpenses: [Expense] {
        let expenses = expensesManager.expenses.sorted { $0.date > $1.date }
        if selectedCategory == "All" {
            return expenses
        }
        return expenses.filter { $0.category.lowercased().contains(selectedCategory.lowercased()) }
    }
    
    var totalAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var monthlyIncome: Double {
        let calendar = Calendar.current
        return bankingManager.transactions
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }
    
    var totalLoggedExpenses: Double {
        expensesManager.expenses.reduce(0) { $0 + $1.amount }
    }
    
    var netBalance: Double {
        monthlyIncome - totalLoggedExpenses
    }
    
    var currentMonthDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            bankingSummary
                .padding(.horizontal)
                .padding(.top)
            
            // Header with total
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Spent")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("$\(totalAmount, specifier: "%.2f")")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            
            ScrollView {
                if filteredExpenses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 60))
                            .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.5))
                        Text("No expenses yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Tap + to add your first expense")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredExpenses) { expense in
                            EnhancedExpenseCard(expense: expense)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("Expenses")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddExpense = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(expensesManager: expensesManager)
        }
        .sheet(isPresented: $showingUpdateBalance) {
            if let uid = authManager.userId {
                UpdateBankBalanceSheet(uid: uid, bankingManager: bankingManager)
            }
        }
        .sheet(isPresented: $showingAddDeposit) {
            if let uid = authManager.userId {
                AddBankDepositSheet(uid: uid, bankingManager: bankingManager)
            }
        }
        .task {
            if let userId = authManager.userId {
                try? await expensesManager.fetchExpenses(uid: userId)
                await bankingManager.fetchBankingData(uid: userId)
            }
        }
    }
}

extension EnhancedExpensesView {
    var bankingSummary: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Balance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("$\(netBalance, specifier: "%.2f")")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(currentMonthDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Deposits − Expenses")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 12) {
                SummaryStatCard(
                    title: "Deposits",
                    amount: monthlyIncome,
                    icon: "arrow.down.circle.fill",
                    color: Color(red: 0.2, green: 0.7, blue: 0.5)
                )
                SummaryStatCard(
                    title: "Expenses",
                    amount: totalLoggedExpenses,
                    icon: "arrow.up.circle.fill",
                    color: Color(red: 0.9, green: 0.4, blue: 0.4)
                )
            }
            
            HStack(spacing: 12) {
                Button(action: { showingUpdateBalance = true }) {
                    Label("Update Balance", systemImage: "pencil")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Button(action: { showingAddDeposit = true }) {
                    Label("Add Deposit", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.15))
                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                .cornerRadius(12)
            }
            
            Text("Keep deposits and expenses updated to maintain an accurate balance.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct SummaryStatCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.headline)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(amount, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct UpdateBankBalanceSheet: View {
    let uid: String
    @ObservedObject var bankingManager: BankingManager
    @Environment(\.dismiss) private var dismiss
    @State private var balanceText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    init(uid: String, bankingManager: BankingManager) {
        self.uid = uid
        self._bankingManager = ObservedObject(wrappedValue: bankingManager)
        self._balanceText = State(initialValue: String(format: "%.2f", bankingManager.currentBalance))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Current Balance") {
                    TextField("Amount", text: $balanceText)
                        .keyboardType(.decimalPad)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Bank Balance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveBalance() }
                        .disabled(isSaving)
                }
            }
        }
    }
    
    private func saveBalance() {
        guard let amount = Double(balanceText) else {
            errorMessage = "Enter a valid number"
            return
        }
        isSaving = true
        Task {
            do {
                try await bankingManager.updateBalance(uid: uid, newBalance: amount)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

struct AddBankDepositSheet: View {
    let uid: String
    @ObservedObject var bankingManager: BankingManager
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var source = ""
    @State private var note = ""
    @State private var type: BankTransaction.TransactionType = .paycheck
    @State private var date = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    init(uid: String, bankingManager: BankingManager) {
        self.uid = uid
        self._bankingManager = ObservedObject(wrappedValue: bankingManager)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Deposit Details") {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    TextField("Source (e.g. Employer)", text: $source)
                    TextField("Note", text: $note)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Type", selection: $type) {
                        ForEach(BankTransaction.TransactionType.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Add Deposit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveDeposit() }
                        .disabled(isSaving)
                }
            }
        }
    }
    
    private func saveDeposit() {
        guard let amount = Double(amountText), amount > 0 else {
            errorMessage = "Enter a positive amount"
            return
        }
        guard !source.isEmpty else {
            errorMessage = "Enter a source"
            return
        }
        isSaving = true
        let transaction = BankTransaction(
            amount: amount,
            source: source,
            note: note.isEmpty ? "Deposit" : note,
            date: date,
            type: type,
            createdAt: Date()
        )
        Task {
            do {
                try await bankingManager.addTransaction(uid: uid, transaction: transaction)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

struct EnhancedExpenseCard: View {
    let expense: Expense
    
    var categoryIcon: String {
        switch expense.category {
        case "Food": return "fork.knife"
        case "Transportation": return "car.fill"
        case "Entertainment": return "popcorn.fill"
        case "Shopping": return "bag.fill"
        case "Bills": return "doc.text.fill"
        default: return "dollarsign.circle.fill"
        }
    }
    
    var categoryColor: Color {
        switch expense.category {
        case "Food": return Color(red: 0.3, green: 0.8, blue: 0.6)
        case "Transportation": return Color(red: 0.25, green: 0.75, blue: 0.55)
        case "Entertainment": return Color(red: 0.35, green: 0.85, blue: 0.65)
        case "Shopping": return Color(red: 0.2, green: 0.7, blue: 0.5)
        case "Bills": return Color(red: 0.15, green: 0.65, blue: 0.45)
        default: return Color(red: 0.25, green: 0.75, blue: 0.55)
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: categoryIcon)
                    .foregroundColor(categoryColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.merchant)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(expense.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(formatDate(expense.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("$\(expense.amount, specifier: "%.2f")")
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
