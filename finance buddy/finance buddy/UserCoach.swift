import Foundation


// Renamed to avoid conflict with QuestionnaireResponse in Models/Questionnaire.swift
struct UserCoachQuestionnaireResponse: Codable, Identifiable {
var id: String = UUID().uuidString
var uid: String
var createdAt: Date = Date()


// Example prompts — tweak as needed
var primaryGoal: String // e.g., "Build $2k emergency fund"
var deadlineISO: String? // e.g., "2025-12-01"
var monthlyIncome: Double
var monthlyFixedCosts: Double
var avgDiscretionary: Double
var riskTolerance: String // "low" | "medium" | "high"
var savingsHabit: String // e.g., "weekly auto-transfer $25"
var blockers: String // free text
}


struct GoalContext: Codable {
var goalTitle: String
var targetAmount: Double
var endDateISO: String? // align with your Goal model
var progressAmount: Double
}


struct Advice: Codable, Identifiable {
var id: String = UUID().uuidString
var uid: String
var createdAt: Date = Date()


// High-level summary
var headline: String // "You're slightly behind, but back on track with 3 changes"
var rationale: String // concise reasoning


// Concrete, atomic actions
struct Action: Codable { let title: String; let why: String; let how: String; let expectedImpact: String }
var actions: [Action]


// Notifications the app can schedule or display
struct Nudges: Codable { let when: String; let message: String }
var nudges: [Nudges]


// Risk flags to surface in UI
var risks: [String]


// Numbers for UI widgets
var weeklySaveSuggestion: Double?
var recommendedBudgetCaps: [String: Double]? // {"Dining": 120, "Shopping": 80}
}