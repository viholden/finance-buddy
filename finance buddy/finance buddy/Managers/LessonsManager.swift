import Foundation
import FirebaseFirestore

class LessonsManager: ObservableObject {
    private let db = Firestore.firestore()
    @Published var availableLessons: [Lesson] = []
    @Published var lessonsProgress: [LessonProgress] = []
    @Published var isLoading = false
    
    init() {
        loadAvailableLessons()
    }
    
    private func loadAvailableLessons() {
        availableLessons = [
            Lesson(id: "lesson1", title: "Budgeting Basics", description: "Learn how to create and stick to a budget", pointsReward: 50, duration: "10 min", difficulty: "Beginner"),
            Lesson(id: "lesson2", title: "Saving Strategies", description: "Discover effective ways to save money", pointsReward: 75, duration: "15 min", difficulty: "Beginner"),
            Lesson(id: "lesson3", title: "Understanding Credit", description: "Master credit scores and credit cards", pointsReward: 100, duration: "20 min", difficulty: "Intermediate"),
            Lesson(id: "lesson4", title: "Investment Fundamentals", description: "Introduction to investing and building wealth", pointsReward: 150, duration: "25 min", difficulty: "Advanced"),
            Lesson(id: "lesson5", title: "Debt Management", description: "Strategies for paying off debt efficiently", pointsReward: 100, duration: "20 min", difficulty: "Intermediate")
        ]
    }
    
    func fetchLessonsProgress(uid: String) async throws {
        await MainActor.run { self.isLoading = true }
        
        let snapshot = try await db.collection("users").document(uid).collection("lessonsProgress").getDocuments()
        
        let progress = snapshot.documents.compactMap { doc -> LessonProgress? in
            try? doc.data(as: LessonProgress.self)
        }
        
        await MainActor.run {
            self.lessonsProgress = progress
            self.isLoading = false
        }
    }
    
    func completeLesson(uid: String, lessonId: String, pointsEarned: Int) async throws {
        let progressId = UUID().uuidString
        let progress = LessonProgress(
            id: progressId,
            lessonId: lessonId,
            status: .completed,
            completedAt: Date(),
            pointsEarned: pointsEarned
        )
        
        let docRef = db.collection("users").document(uid).collection("lessonsProgress").document(progressId)
        try docRef.setData(from: progress)
        
        try await db.collection("users").document(uid).updateData([
            "totalPoints": FieldValue.increment(Int64(pointsEarned))
        ])
        
        await MainActor.run {
            self.lessonsProgress.append(progress)
        }
    }
    
    func getLessonStatus(lessonId: String) -> LessonStatus {
        if let progress = lessonsProgress.first(where: { $0.lessonId == lessonId }) {
            return progress.status
        }
        return .notStarted
    }
}
