import Foundation

struct Lesson: Codable, Identifiable {
    var id: String
    var title: String
    var description: String
    var pointsReward: Int
    var duration: String
    var difficulty: String
}

struct LessonProgress: Codable, Identifiable {
    var id: String = UUID().uuidString
    var lessonId: String
    var status: LessonStatus
    var completedAt: Date?
    var pointsEarned: Int
}

enum LessonStatus: String, Codable {
    case notStarted = "notStarted"
    case inProgress = "inProgress"
    case completed = "completed"
}
