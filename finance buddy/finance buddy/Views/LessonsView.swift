import SwiftUI

struct LessonsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @StateObject private var lessonsManager = LessonsManager()
    
    var body: some View {
        ZStack {
            if lessonsManager.isLoading {
                ProgressView()
            } else {
                List(lessonsManager.availableLessons) { lesson in
                    NavigationLink(destination: LessonDetailView(lessonsManager: lessonsManager, lesson: lesson)) {
                        LessonRowView(lesson: lesson, lessonsManager: lessonsManager)
                    }
                }
            }
        }
        .navigationTitle("Learn & Earn")
        .task {
            if let uid = authManager.user?.uid {
                try? await lessonsManager.fetchLessonsProgress(uid: uid)
            }
        }
    }
}

struct LessonRowView: View {
    let lesson: Lesson
    @ObservedObject var lessonsManager: LessonsManager
    
    var status: LessonStatus {
        lessonsManager.getLessonStatus(lessonId: lesson.id)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.headline)
                
                Text(lesson.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Label("\(lesson.pointsReward) pts", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(lesson.duration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(lesson.difficulty)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            }
        }
        .padding(.vertical, 8)
    }
    
    var statusIcon: String {
        switch status {
        case .notStarted: return "book"
        case .inProgress: return "book.pages"
        case .completed: return "checkmark"
        }
    }
    
    var statusColor: Color {
        switch status {
        case .notStarted: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
}

struct LessonDetailView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @ObservedObject var lessonsManager: LessonsManager
    let lesson: Lesson
    @State private var showingCompletion = false
    
    var isCompleted: Bool {
        lessonsManager.getLessonStatus(lessonId: lesson.id) == .completed
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(lesson.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Label("\(lesson.pointsReward) Points", systemImage: "star.fill")
                            .foregroundColor(.orange)
                        Text("•")
                        Text(lesson.duration)
                        Text("•")
                        Text(lesson.difficulty)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("About This Lesson")
                        .font(.headline)
                    
                    Text(lesson.description)
                        .foregroundColor(.secondary)
                    
                    Text("In this lesson, you'll learn essential financial concepts that will help you make better decisions with your money.")
                        .foregroundColor(.secondary)
                }
                
                if !isCompleted {
                    Button(action: {
                        completeLesson()
                    }) {
                        Text("Complete Lesson")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Completed")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .navigationTitle("Lesson")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Lesson Complete!", isPresented: $showingCompletion) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You earned \(lesson.pointsReward) points! 🎉")
        }
    }
    
    private func completeLesson() {
        guard let uid = authManager.user?.uid else { return }
        
        Task {
            try? await lessonsManager.completeLesson(uid: uid, lessonId: lesson.id, pointsEarned: lesson.pointsReward)
            
            if firestoreManager.userProfile != nil {
                await MainActor.run {
                    firestoreManager.userProfile?.totalPoints += lesson.pointsReward
                    showingCompletion = true
                }
            }
        }
    }
}
