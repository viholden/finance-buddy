import Foundation
import FirebaseFirestore
import FirebaseAuth

class ExpensesManager: ObservableObject {
    private let db = Firestore.firestore()
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    
    func fetchExpenses(uid: String) async throws {
        await MainActor.run { self.isLoading = true }
        
        let snapshot = try await db.collection("users").document(uid).collection("expenses")
            .order(by: "date", descending: true)
            .getDocuments()
        
        let fetchedExpenses = snapshot.documents.compactMap { doc -> Expense? in
            try? doc.data(as: Expense.self)
        }
        
        await MainActor.run {
            self.expenses = fetchedExpenses
            self.isLoading = false
        }
    }
    
    func addExpense(uid: String, expense: Expense) async throws {
        let docRef = db.collection("users").document(uid).collection("expenses").document(expense.id)
        try docRef.setData(from: expense)
        
        await MainActor.run {
            self.expenses.insert(expense, at: 0)
        }
    }
    
    func deleteExpense(uid: String, expenseId: String) async throws {
        try await db.collection("users").document(uid).collection("expenses").document(expenseId).delete()
        
        await MainActor.run {
            self.expenses.removeAll { $0.id == expenseId }
        }
    }
    
    func getTotalSpent() -> Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    func getExpensesByCategory() -> [String: Double] {
        Dictionary(grouping: expenses, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }
}
