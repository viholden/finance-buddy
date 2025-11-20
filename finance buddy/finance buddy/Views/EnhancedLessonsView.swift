import SwiftUI

struct EnhancedLessonsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var lessonsManager = LessonsManager()
    
    var completedLessonIds: Set<String> {
        Set(lessonsManager.lessonsProgress.filter { $0.status == .completed }.map { $0.lessonId })
    }
    
    var completedLessons: [Lesson] {
        lessonsManager.availableLessons.filter { completedLessonIds.contains($0.id) }
    }
    
    var incompleteLessons: [Lesson] {
        lessonsManager.availableLessons.filter { !completedLessonIds.contains($0.id) }
    }
    
    var totalPoints: Int {
        completedLessons.reduce(0) { $0 + $1.pointsReward }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Progress Header
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.15, green: 0.65, blue: 0.45), Color(red: 0.25, green: 0.75, blue: 0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Learning Streak")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                Text("7 Days 🔥")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Total Points")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                Text("\(totalPoints)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        HStack(spacing: 16) {
                            StatBadge(icon: "checkmark.circle.fill", value: "\(completedLessons.count)", label: "Completed")
                            StatBadge(icon: "book.fill", value: "\(lessonsManager.availableLessons.count)", label: "Total")
                            StatBadge(icon: "star.fill", value: "\(totalPoints)", label: "Points")
                        }
                    }
                    .padding(24)
                }
                .frame(height: 180)
                .padding(.horizontal)
                
                // Continue Learning
                if !incompleteLessons.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Continue Learning")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(incompleteLessons.prefix(3)) { lesson in
                            LessonCard(lesson: lesson)
                                .padding(.horizontal)
                        }
                    }
                } else if lessonsManager.availableLessons.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.5))
                        Text("No lessons available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
                
                // Completed Lessons
                if !completedLessons.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Completed")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(completedLessons) { lesson in
                            CompletedLessonCard(lesson: lesson)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Learn")
        .task {
            if let userId = authManager.userId {
                try? await lessonsManager.fetchLessonsProgress(uid: userId)
            }
        }
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(label)
                    .font(.caption2)
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
    }
}

struct LessonCard: View {
    let lesson: Lesson
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "book.fill")
                    .font(.title2)
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(lesson.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.2), lineWidth: 3)
                        .frame(width: 36, height: 36)
                    
                    Text("+\(lesson.pointsReward)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct CompletedLessonCard: View {
    let lesson: Lesson
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Completed • +\(lesson.pointsReward) pts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "arrow.right.circle.fill")
                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.3))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
