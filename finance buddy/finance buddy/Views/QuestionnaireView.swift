//
//  QuestionnaireView.swift
//  finance buddy
//
//  Created by Hannah Holden on 10/15/25.
//

import SwiftUI

struct QuestionnaireView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentQuestionIndex = 0
    @State private var responses: [String: Any] = [:]
    @State private var isLoading = false
    
    let email: String
    let password: String
    let name: String
    let onComplete: (QuestionnaireResponse) -> Void
    
    var currentQuestion: Question {
        QuestionnaireManager.questions[currentQuestionIndex]
    }
    
    var progressPercentage: Double {
        Double(currentQuestionIndex + 1) / Double(QuestionnaireManager.questions.count)
    }
    
    var isAnswered: Bool {
        responses[currentQuestion.id] != nil
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.65, blue: 0.45).opacity(0.1),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Button(action: { dismiss() }) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text("Let's Get Started")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Step \(currentQuestionIndex + 1) of \(QuestionnaireManager.questions.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Placeholder for symmetry
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 36, height: 36)
                    }
                    
                    // Progress bar
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.15, green: 0.65, blue: 0.45),
                                        Color(red: 0.25, green: 0.75, blue: 0.55)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: CGFloat(progressPercentage) * (UIScreen.main.bounds.width - 64), height: 8)
                            .animation(.spring(), value: progressPercentage)
                    }
                }
                .padding()
                .background(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Question Title and Description
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "questionmark")
                                        .font(.title3)
                                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(currentQuestion.title)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Text(currentQuestion.description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Question Content
                        VStack(spacing: 12) {
                            switch currentQuestion.type {
                            case .singleChoice:
                                SingleChoiceQuestionView(
                                    options: currentQuestion.options ?? [],
                                    selectedAnswer: responses[currentQuestion.id] as? String,
                                    onSelect: { answer in
                                        responses[currentQuestion.id] = answer
                                    }
                                )
                                
                            case .multipleChoice:
                                MultipleChoiceQuestionView(
                                    options: currentQuestion.options ?? [],
                                    selectedAnswers: responses[currentQuestion.id] as? [String] ?? [],
                                    onSelect: { answers in
                                        responses[currentQuestion.id] = answers
                                    }
                                )
                                
                            case .text:
                                TextQuestionView(
                                    text: (responses[currentQuestion.id] as? String) ?? "",
                                    onTextChange: { text in
                                        responses[currentQuestion.id] = text
                                    }
                                )
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
                
                // Navigation Buttons
                VStack(spacing: 12) {
                    Button(action: completeQuestionnaire) {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                HStack {
                                    Text(currentQuestionIndex == QuestionnaireManager.questions.count - 1 ? "Complete Setup" : "Next")
                                        .fontWeight(.semibold)
                                    
                                    Image(systemName: currentQuestionIndex == QuestionnaireManager.questions.count - 1 ? "checkmark" : "arrow.right")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            isAnswered ?
                            LinearGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.65, blue: 0.45),
                                    Color(red: 0.25, green: 0.75, blue: 0.55)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [Color.gray, Color.gray],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(color: isAnswered ? Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                    }
                    .disabled(!isAnswered || isLoading)
                    .opacity(!isAnswered || isLoading ? 0.6 : 1.0)
                    
                    if currentQuestionIndex > 0 {
                        Button(action: previousQuestion) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Back")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color(red: 0.2, green: 0.7, blue: 0.5), lineWidth: 2)
                            )
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: -2)
            }
        }
    }
    
    private func nextQuestion() {
        if currentQuestionIndex < QuestionnaireManager.questions.count - 1 {
            currentQuestionIndex += 1
        }
    }
    
    private func previousQuestion() {
        if currentQuestionIndex > 0 {
            currentQuestionIndex -= 1
        }
    }
    
    private func completeQuestionnaire() {
        if currentQuestionIndex < QuestionnaireManager.questions.count - 1 {
            nextQuestion()
        } else {
            isLoading = true
            let questionnaireResponse = buildQuestionnaireResponse()
            onComplete(questionnaireResponse)
        }
    }
    
    private func buildQuestionnaireResponse() -> QuestionnaireResponse {
        return QuestionnaireResponse(
            financialGoal: responses["financial_goal"] as? String,
            incomeRange: responses["income_range"] as? String,
            expenses: responses["major_expenses"] as? [String],
            riskTolerance: responses["risk_tolerance"] as? String,
            savingsExperience: responses["savings_experience"] as? String,
            primaryConcerns: responses["primary_concerns"] as? [String],
            additionalComments: responses["additional_comments"] as? String,
            updatedAt: Date()
        )
    }
}

// MARK: - Question Type Views

struct SingleChoiceQuestionView: View {
    let options: [String]
    let selectedAnswer: String?
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(options, id: \.self) { option in
                Button(action: { 
                    withAnimation(.spring(response: 0.3)) {
                        onSelect(option)
                    }
                }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(selectedAnswer == option ? Color(red: 0.2, green: 0.7, blue: 0.5) : Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            
                            if selectedAnswer == option {
                                Circle()
                                    .fill(Color(red: 0.2, green: 0.7, blue: 0.5))
                                    .frame(width: 12, height: 12)
                            }
                        }
                        
                        Text(option)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        if selectedAnswer == option {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .padding(16)
                    .background(selectedAnswer == option ? Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.1) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedAnswer == option ? Color(red: 0.2, green: 0.7, blue: 0.5) : Color.gray.opacity(0.2), lineWidth: selectedAnswer == option ? 2 : 1)
                    )
                    .cornerRadius(12)
                    .shadow(color: selectedAnswer == option ? Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.2) : .clear, radius: 8, x: 0, y: 2)
                }
            }
        }
    }
}

struct MultipleChoiceQuestionView: View {
    let options: [String]
    let selectedAnswers: [String]
    let onSelect: ([String]) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        var updated = selectedAnswers
                        if let index = updated.firstIndex(of: option) {
                            updated.remove(at: index)
                        } else {
                            updated.append(option)
                        }
                        onSelect(updated)
                    }
                }) {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selectedAnswers.contains(option) ? Color(red: 0.2, green: 0.7, blue: 0.5) : Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            
                            if selectedAnswers.contains(option) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        
                        Text(option)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(selectedAnswers.contains(option) ? Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.1) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedAnswers.contains(option) ? Color(red: 0.2, green: 0.7, blue: 0.5) : Color.gray.opacity(0.2), lineWidth: selectedAnswers.contains(option) ? 2 : 1)
                    )
                    .cornerRadius(12)
                    .shadow(color: selectedAnswers.contains(option) ? Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.2) : .clear, radius: 8, x: 0, y: 2)
                }
            }
        }
    }
}

struct TextQuestionView: View {
    @State var text: String
    let onTextChange: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.3), lineWidth: 1)
                
                TextEditor(text: $text)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                
                if text.isEmpty {
                    Text("Share your thoughts...")
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: text, initial: false) { oldValue, newValue in
                onTextChange(newValue)
            }
            
            Text("\(text.count) characters")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

#Preview {
    QuestionnaireView(
        email: "test@example.com",
        password: "password",
        name: "John Doe",
        onComplete: { _ in }
    )
}
