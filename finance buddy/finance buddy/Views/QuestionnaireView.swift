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
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("Step \(currentQuestionIndex + 1) of \(QuestionnaireManager.questions.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: progressPercentage)
                    .tint(.blue)
            }
            .padding()
            .background(Color(.systemGray6))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Question Title and Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentQuestion.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(currentQuestion.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text(currentQuestionIndex == QuestionnaireManager.questions.count - 1 ? "Complete Setup" : "Next")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(isAnswered ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!isAnswered || isLoading)
                
                if currentQuestionIndex > 0 {
                    Button(action: previousQuestion) {
                        Text("Back")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
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
                Button(action: { onSelect(option) }) {
                    HStack(spacing: 12) {
                        Image(systemName: selectedAnswer == option ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedAnswer == option ? .blue : .gray)
                        
                        Text(option)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(selectedAnswer == option ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .cornerRadius(8)
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
                    var updated = selectedAnswers
                    if let index = updated.firstIndex(of: option) {
                        updated.remove(at: index)
                    } else {
                        updated.append(option)
                    }
                    onSelect(updated)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: selectedAnswers.contains(option) ? "checkmark.square.fill" : "square")
                            .foregroundColor(selectedAnswers.contains(option) ? .blue : .gray)
                        
                        Text(option)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(selectedAnswers.contains(option) ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct TextQuestionView: View {
    @State var text: String
    let onTextChange: (String) -> Void
    
    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: 100)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .onChange(of: text, initial: false) { oldValue, newValue in
                onTextChange(newValue)
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
