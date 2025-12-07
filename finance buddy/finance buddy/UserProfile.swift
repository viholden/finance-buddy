import Foundation
import FirebaseFirestore

struct UserProfile: Codable {
    var name: String
    var email: String
    var profilePictureURL: String?
    var totalPoints: Int
    var currency: String
    var darkMode: Bool
    var createdAt: Date
    var lastLogin: Date
    var preferences: Preferences
    var bankBalance: Double = 0
    var lastBankUpdate: Date? = nil
    var questionnaireResponses: QuestionnaireResponse?
    
    struct Preferences: Codable {
        var notifications: Bool
        var language: String
    }
}
