import Foundation
import FirebaseFirestore

@MainActor
class BankingManager: ObservableObject {
    @Published var currentBalance: Double = 0
    @Published var lastUpdated: Date?
    @Published var transactions: [BankTransaction] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    
    func fetchBankingData(uid: String) async {
        isLoading = true
        error = nil
        
        do {
            let userDoc = try await db.collection("users").document(uid).getDocument()
            if let data = userDoc.data() {
                let balance = data["bankBalance"] as? Double ?? 0
                let timestamp = (data["lastBankUpdate"] as? Timestamp)?.dateValue()
                self.currentBalance = balance
                self.lastUpdated = timestamp
            }
            
            let snapshot = try await db.collection("users").document(uid)
                .collection("bankTransaction")
                .order(by: "date", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            let fetched = snapshot.documents.compactMap { doc -> BankTransaction? in
                let data = doc.data()
                                guard let amount = data["amount"] as? Double,
                                            let source = data["source"] as? String,
                      let typeRaw = data["type"] as? String,
                      let type = BankTransaction.TransactionType(rawValue: typeRaw),
                      let date = (data["date"] as? Timestamp)?.dateValue(),
                      let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                return BankTransaction(
                    id: doc.documentID,
                    amount: amount,
                                        source: source,
                                        note: data["note"] as? String ?? "Deposit",
                    date: date,
                    type: type,
                    createdAt: createdAt
                )
            }
            
            self.transactions = fetched
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func updateBalance(uid: String, newBalance: Double) async throws {
        let now = Date()
        try await db.collection("users").document(uid).updateData([
            "bankBalance": newBalance,
            "lastBankUpdate": Timestamp(date: now)
        ])
        
        self.currentBalance = newBalance
        self.lastUpdated = now
    }
    
    func addTransaction(uid: String, transaction: BankTransaction) async throws {
        let doc = db.collection("users").document(uid)
            .collection("bankTransaction")
            .document(transaction.id)
        
        try await doc.setData([
            "amount": transaction.amount,
            "source": transaction.source,
            "note": transaction.note,
            "type": transaction.type.rawValue,
            "date": Timestamp(date: transaction.date),
            "createdAt": Timestamp(date: transaction.createdAt)
        ])
        
        let updatedBalance = currentBalance + transaction.amount
        try await updateBalance(uid: uid, newBalance: updatedBalance)
        transactions.insert(transaction, at: 0)
    }
}
