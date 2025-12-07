import Foundation

struct BankTransaction: Identifiable, Codable, Hashable {
    enum TransactionType: String, Codable, CaseIterable, Identifiable {
        case paycheck
        case deposit
        case other
        
        var id: String { rawValue }
        
        var label: String {
            switch self {
            case .paycheck: return "Paycheck"
            case .deposit: return "Deposit"
            case .other: return "Other"
            }
        }
        
        var iconName: String {
            switch self {
            case .paycheck: return "dollarsign.arrow.circlepath"
            case .deposit: return "arrow.down.circle.fill"
            case .other: return "plus.circle.fill"
            }
        }
    }
    
    var id: String = UUID().uuidString
    var amount: Double
    var source: String
    var note: String
    var date: Date
    var type: TransactionType
    var createdAt: Date
}
