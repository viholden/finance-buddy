//
//  Questionnaire.swift
//  finance buddy
//
//  Created by A'Kaia Phelps on 10/15/25.
//

import Foundation

struct QuestionnaireResponse: Codable {
    var financialGoal: String?
    var incomeRange: String?
    var expenses: [String]?
    var riskTolerance: String?
    var savingsExperience: String?
    var primaryConcerns: [String]?
    var additionalComments: String?
    var updatedAt: Date?
}

struct QuestionnaireHistoryEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var financialGoal: String?
    var incomeRange: String?
    var expenses: [String]?
    var riskTolerance: String?
    var savingsExperience: String?
    var primaryConcerns: [String]?
    var additionalComments: String?
    var timestamp: Date
    var changeNote: String?
}

struct Question {
    let id: String
    let title: String
    let description: String
    let type: QuestionType
    let options: [String]?
    let required: Bool
}

enum QuestionType {
    case singleChoice
    case multipleChoice
    case text
}

class QuestionnaireManager {
    static let questions: [Question] = [
        Question(
            id: "financial_goal",
            title: "What is your primary financial goal?",
            description: "Understanding your goals helps us personalize your experience",
            type: .singleChoice,
            options: [
                "Save for emergency fund",
                "Pay off debt",
                "Save for a purchase",
                "Build long-term wealth",
                "Learn about personal finance",
                "Track spending"
            ],
            required: true
        ),
        Question(
            id: "income_range",
            title: "What is your approximate annual income range?",
            description: "This helps us provide relevant financial insights",
            type: .singleChoice,
            options: [
                "Under $20,000",
                "$20,000 - $50,000",
                "$50,000 - $100,000",
                "$100,000 - $200,000",
                "$200,000+",
                "Prefer not to say"
            ],
            required: true
        ),
        Question(
            id: "major_expenses",
            title: "What are your major expense categories?",
            description: "Select all that apply to help us categorize your spending",
            type: .multipleChoice,
            options: [
                "Housing (rent/mortgage)",
                "Food & Groceries",
                "Transportation",
                "Utilities",
                "Entertainment",
                "Healthcare",
                "Education",
                "Shopping",
                "Subscriptions",
                "Other"
            ],
            required: true
        ),
        Question(
            id: "risk_tolerance",
            title: "How comfortable are you with financial risk?",
            description: "This helps tailor investment and saving recommendations",
            type: .singleChoice,
            options: [
                "Very conservative - I prioritize safety",
                "Somewhat conservative - I prefer stability",
                "Moderate - I balance growth and safety",
                "Somewhat aggressive - I'm open to growth",
                "Very aggressive - I seek maximum growth"
            ],
            required: true
        ),
        Question(
            id: "savings_experience",
            title: "How would you rate your experience with budgeting and saving?",
            description: "This helps us provide appropriate guidance",
            type: .singleChoice,
            options: [
                "Beginner - I'm new to budgeting",
                "Intermediate - I have some experience",
                "Advanced - I actively manage my finances",
                "Expert - I'm very knowledgeable"
            ],
            required: true
        ),
        Question(
            id: "primary_concerns",
            title: "What are your main financial concerns?",
            description: "Select all that apply",
            type: .multipleChoice,
            options: [
                "Living paycheck to paycheck",
                "High debt levels",
                "Lack of savings",
                "Unclear spending habits",
                "Insufficient emergency fund",
                "Difficulty reaching financial goals",
                "Limited financial knowledge",
                "Investment uncertainty"
            ],
            required: false
        ),
        Question(
            id: "additional_comments",
            title: "Tell me anything!",
            description: "Feel free to share anything else you'd like us to know about your financial journey",
            type: .text,
            options: nil,
            required: false
        )
    ]
}
