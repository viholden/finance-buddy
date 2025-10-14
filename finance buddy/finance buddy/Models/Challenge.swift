import Foundation

struct Challenge: Codable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var description: String
    var status: ChallengeStatus
    var startDate: Date
    var endDate: Date
    var pointsAwarded: Int
    var targetAmount: Double?
    var currentAmount: Double?
    var progressPercent: Double
}

enum ChallengeStatus: String, Codable {
    case active = "active"
    case completed = "completed"
    case failed = "failed"
}
