import Foundation

struct AppNotification: Codable, Identifiable {
    var id: String = UUID().uuidString
    var type: String
    var message: String
    var read: Bool
    var sentAt: Date
}

enum NotificationType: String {
    case goalReminder = "goalReminder"
    case challengeUpdate = "challengeUpdate"
    case lessonComplete = "lessonComplete"
    case expenseAlert = "expenseAlert"
}
