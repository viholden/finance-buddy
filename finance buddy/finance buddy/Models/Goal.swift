import Foundation

struct Goal: Codable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var deadline: Date
    var progressPercent: Double
    var remindersEnabled: Bool
    
    var isCompleted: Bool {
        currentAmount >= targetAmount
    }
}
