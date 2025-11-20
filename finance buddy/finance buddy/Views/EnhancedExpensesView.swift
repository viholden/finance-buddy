import SwiftUI

struct EnhancedExpensesView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var expensesManager = ExpensesManager()
    @State private var showingAddExpense = false
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
    
    var body: some View {
        VStack(spacing: 0) {
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
        .task {
            if let userId = authManager.userId {
                try? await expensesManager.fetchExpenses(uid: userId)
            }
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
