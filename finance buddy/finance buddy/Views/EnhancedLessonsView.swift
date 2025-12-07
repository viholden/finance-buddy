import SwiftUI

struct EnhancedLessonsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var lessonsManager = LessonsManager()
    @State private var selectedLesson: InteractiveLesson?
    private let interactiveLessons: [InteractiveLesson] = [
        InteractiveLesson(
            title: "Lesson 1: Building a Starter Budget",
            previewDescription: "Learn the basics of creating a simple budget that actually works for students and young professionals.",
            fullContent: "A budget helps you understand where your money goes and how to plan ahead. The easiest way to start is with the 50/30/20 rule:\n\n50% Needs (rent, groceries, bills)\n30% Wants (shopping, dining out, entertainment)\n20% Savings/Debt (goals, emergency fund, loans)",
            takeaways: [
                "Know your monthly income",
                "List fixed expenses",
                "Track flexible spending",
                "Set one short-term & one long-term goal"
            ],
            quizQuestion: "Which category does dining out fall under?",
            quizOptions: [
                QuizOption(text: "Needs"),
                QuizOption(text: "Wants", isCorrect: true),
                QuizOption(text: "Savings")
            ],
            icon: "chart.pie.fill",
            accent: Color(red: 0.2, green: 0.7, blue: 0.5)
        ),
        InteractiveLesson(
            title: "Lesson 2: How to Build an Emergency Fund",
            previewDescription: "Understand why an emergency fund is your financial safety net and how to start one today.",
            fullContent: "An emergency fund protects you from surprise expenses like car repairs, medical bills, or sudden job loss. For most students and young adults, a good starter target is $500–$1,000.",
            takeaways: [
                "Save a small amount weekly",
                "Keep it in a separate savings account",
                "Avoid touching it unless it’s truly an emergency",
                "Increase the target as your income grows"
            ],
            quizQuestion: "What’s a good beginner emergency fund target?",
            quizOptions: [
                QuizOption(text: "$200"),
                QuizOption(text: "$500–$1,000", isCorrect: true),
                QuizOption(text: "$5,000")
            ],
            icon: "shield.lefthalf.fill",
            accent: Color(red: 0.95, green: 0.55, blue: 0.2)
        ),
        InteractiveLesson(
            title: "Lesson 3: Understanding Credit & Why It Matters",
            previewDescription: "Learn how credit scores work and how to build healthy credit early.",
            fullContent: "Your credit score affects your ability to rent an apartment, get a car, and even some jobs. It’s based on payment history, debt levels, credit age, types of credit, and new credit inquiries.",
            takeaways: [
                "Always pay your credit card on time",
                "Keep usage below 30%",
                "Don’t open too many cards at once",
                "Pay more than the minimum when possible"
            ],
            quizQuestion: "What’s the recommended maximum credit card usage?",
            quizOptions: [
                QuizOption(text: "100%"),
                QuizOption(text: "50%"),
                QuizOption(text: "30%", isCorrect: true)
            ],
            icon: "creditcard.fill",
            accent: Color(red: 0.3, green: 0.35, blue: 0.85)
        )
    ]
    
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
                
                if !interactiveLessons.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Guided Lessons")
                            .font(.headline)
                            .padding(.horizontal)
                        ForEach(interactiveLessons) { lesson in
                            Button {
                                selectedLesson = lesson
                            } label: {
                                LessonPreviewCard(lesson: lesson)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
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
        .sheet(item: $selectedLesson) { lesson in
            LessonDetailSheet(lesson: lesson)
        }
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

struct InteractiveLesson: Identifiable {
    let id = UUID()
    let title: String
    let previewDescription: String
    let fullContent: String
    let takeaways: [String]
    let quizQuestion: String
    let quizOptions: [QuizOption]
    let icon: String
    let accent: Color
}

struct QuizOption: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let isCorrect: Bool
    
    init(text: String, isCorrect: Bool = false) {
        self.text = text
        self.isCorrect = isCorrect
    }
}

struct LessonPreviewCard: View {
    let lesson: InteractiveLesson
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(lesson.accent.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: lesson.icon)
                    .foregroundColor(lesson.accent)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(lesson.title)
                    .font(.headline)
                Text(lesson.previewDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 12)
            Image(systemName: "chevron.right.circle.fill")
                .foregroundColor(lesson.accent.opacity(0.8))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct LessonDetailSheet: View {
    let lesson: InteractiveLesson
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOption: QuizOption?
    @State private var showFeedback = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    detailHeader
                    Divider()
                    lessonBody
                    lessonTakeaways
                    quizSection
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(lesson.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private var detailHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(lesson.accent.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: lesson.icon)
                    .foregroundColor(lesson.accent)
                    .font(.system(size: 32))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Overview")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(lesson.previewDescription)
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var lessonBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Full Lesson")
            Text(lesson.fullContent)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var lessonTakeaways: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Takeaways")
            ForEach(lesson.takeaways, id: \.self) { takeaway in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(lesson.accent)
                    Text(takeaway)
                        .foregroundColor(.primary)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 1)
            }
        }
    }
    
    private var quizSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Quiz")
            Text(lesson.quizQuestion)
                .font(.subheadline)
                .foregroundColor(.secondary)
            VStack(spacing: 12) {
                ForEach(lesson.quizOptions) { option in
                    Button {
                        selectedOption = option
                        showFeedback = true
                    } label: {
                        HStack {
                            Text(option.text)
                                .fontWeight(.medium)
                            Spacer()
                            if selectedOption == option {
                                Image(systemName: option.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(option.isCorrect ? .green : .red)
                            }
                        }
                        .padding()
                        .background(optionBackground(option))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(optionBorder(option), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            if showFeedback, let choice = selectedOption {
                Text(choice.isCorrect ? "Nice! That’s the right answer." : "Not quite—give it another look.")
                    .font(.footnote)
                    .foregroundColor(choice.isCorrect ? .green : .red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func optionBackground(_ option: QuizOption) -> Color {
        guard let selectedOption else { return Color(.systemGray6) }
        if selectedOption == option {
            return option.isCorrect ? Color.green.opacity(0.15) : Color.red.opacity(0.15)
        }
        return Color(.systemGray6)
    }
    
    private func optionBorder(_ option: QuizOption) -> Color {
        guard let selectedOption else { return Color.clear }
        if selectedOption == option {
            return option.isCorrect ? .green : .red
        }
        return Color.clear
    }
}
