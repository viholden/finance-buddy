import SwiftUI

struct ExpensesView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var expensesManager = ExpensesManager()
    @State private var showingAddExpense = false
    @State private var selectedCategory: String?
    
    var filteredExpenses: [Expense] {
        if let category = selectedCategory {
            return expensesManager.expenses.filter { $0.category == category }
        }
        return expensesManager.expenses
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                HStack {
                    Text("Total Spent")
                        .font(.headline)
                    Spacer()
                    Text("$\(expensesManager.getTotalSpent(), specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            FilterChip(title: category.rawValue, isSelected: selectedCategory == category.rawValue) {
                                selectedCategory = category.rawValue
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            
            if expensesManager.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredExpenses.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text(selectedCategory == nil ? "No Expenses Yet" : "No \(selectedCategory!) Expenses")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Start tracking your spending")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(filteredExpenses) { expense in
                        ExpenseRowView(expense: expense)
                    }
                    .onDelete { indexSet in
                        deleteExpenses(at: indexSet)
                    }
                }
            }
        }
        .navigationTitle("Expenses")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddExpense = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(expensesManager: expensesManager)
        }
        .task {
            if let uid = authManager.user?.uid {
                try? await expensesManager.fetchExpenses(uid: uid)
            }
        }
    }
    
    private func deleteExpenses(at offsets: IndexSet) {
        guard let uid = authManager.user?.uid else { return }
        
        for index in offsets {
            let expense = filteredExpenses[index]
            Task {
                try? await expensesManager.deleteExpense(uid: uid, expenseId: expense.id)
            }
        }
    }
}

struct ExpenseRowView: View {
    let expense: Expense
    
    var categoryIcon: String {
        ExpenseCategory.allCases.first(where: { $0.rawValue == expense.category })?.icon ?? "dollarsign.circle"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.merchant)
                    .font(.headline)
                Text(expense.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(expense.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("-$\(expense.amount, specifier: "%.2f")")
                .font(.headline)
                .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct AddExpenseView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var expensesManager: ExpensesManager
    @Environment(\.dismiss) var dismiss
    
    @State private var amount = ""
    @State private var category = ExpenseCategory.food.rawValue
    @State private var merchant = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var isRecurring = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Expense Details")) {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                Text(cat.rawValue)
                            }
                            .tag(cat.rawValue)
                        }
                    }
                    
                    TextField("Merchant", text: $merchant)
                    TextField("Description", text: $description)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section {
                    Toggle("Recurring Expense", isOn: $isRecurring)
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(amount.isEmpty || merchant.isEmpty)
                }
            }
        }
    }
    
    private func saveExpense() {
        guard let uid = authManager.user?.uid,
              let expenseAmount = Double(amount) else { return }
        
        let expense = Expense(
            amount: expenseAmount,
            category: category,
            merchant: merchant,
            date: date,
            description: description,
            isRecurring: isRecurring,
            uploadedReceipt: nil,
            aiCategoryConfidence: nil,
            createdAt: Date()
        )
        
        Task {
            try? await expensesManager.addExpense(uid: uid, expense: expense)
            await MainActor.run { dismiss() }
        }
    }
}
