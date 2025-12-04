import Foundation
import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

class ExpensesManager: ObservableObject {
    private var db: Firestore?
    @Published var expenses: [Expense] = []
    @Published var isLoading = false

    init() {
        if FirebaseApp.app() != nil { self.db = Firestore.firestore() }
        else { NotificationCenter.default.addObserver(self, selector: #selector(setupFirestoreIfNeeded), name: UIApplication.didFinishLaunchingNotification, object: nil) }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func setupFirestoreIfNeeded() { if FirebaseApp.app() != nil { self.db = Firestore.firestore(); NotificationCenter.default.removeObserver(self) } }

    private func requireDB() throws -> Firestore { if let db = self.db { return db }; throw NSError(domain: "ExpensesManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Firebase is not configured."]) }
    
    func fetchExpenses(uid: String) async throws {
        await MainActor.run { self.isLoading = true }
        
        let db = try requireDB()
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
        let db = try requireDB()
        let docRef = db.collection("users").document(uid).collection("expenses").document(expense.id)
        try docRef.setData(from: expense)
        
        await MainActor.run {
            self.expenses.insert(expense, at: 0)
        }
    }
    
    func deleteExpense(uid: String, expenseId: String) async throws {
        let db = try requireDB()
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
