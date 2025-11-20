import Foundation

struct Expense: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var amount: Double
    var category: String
    var merchant: String
    var date: Date
    var description: String
    var isRecurring: Bool
    var uploadedReceipt: String?
    var aiCategoryConfidence: Double?
    var createdAt: Date
}

enum ExpenseCategory: String, CaseIterable {
    case food = "Food"
    case transport = "Transport"
    case shopping = "Shopping"
    case entertainment = "Entertainment"
    case bills = "Bills"
    case health = "Health"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .shopping: return "cart.fill"
        case .entertainment: return "tv.fill"
        case .bills: return "doc.text.fill"
        case .health: return "heart.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}
