import Foundation
import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

class FirestoreManager: ObservableObject {
    private var db: Firestore?
    @Published var userProfile: UserProfile?
    @Published var isLoading = false

    enum FirestoreManagerError: Error {
        case firebaseNotConfigured
        var localizedDescription: String {
            switch self {
            case .firebaseNotConfigured:
                return "Firebase is not configured. Call FirebaseApp.configure() before using Firestore."
            }
        }
    }

    init() {
        if FirebaseApp.app() != nil {
            self.db = Firestore.firestore()
        } else {
            // Defer initialization until after app finishes launching/configuration
            NotificationCenter.default.addObserver(self, selector: #selector(setupFirestoreIfNeeded), name: UIApplication.didFinishLaunchingNotification, object: nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func setupFirestoreIfNeeded() {
        if FirebaseApp.app() != nil {
            self.db = Firestore.firestore()
            NotificationCenter.default.removeObserver(self)
        }
    }

    private func requireDB() throws -> Firestore {
        if let db = self.db {
            return db
        }
        throw FirestoreManagerError.firebaseNotConfigured
    }
    
    func createUserProfile(uid: String, name: String, email: String, questionnaireResponses: QuestionnaireResponse? = nil) async throws {
        let newProfile = UserProfile(
            name: name,
            email: email,
            profilePictureURL: nil,
            totalPoints: 0,
            currency: "USD",
            darkMode: false,
            createdAt: Date(),
            lastLogin: Date(),
            preferences: UserProfile.Preferences(
                notifications: true,
                language: "en"
            ),
            questionnaireResponses: questionnaireResponses
        )
        
        let db = try requireDB()
        try db.collection("users").document(uid).setData(from: newProfile)
        await MainActor.run {
            self.userProfile = newProfile
        }
    }
    
    func fetchUserProfile(uid: String) async throws {
        await MainActor.run {
            self.isLoading = true
        }

        let db = try requireDB()
        let document = try await db.collection("users").document(uid).getDocument()
        
        if let profile = try? document.data(as: UserProfile.self) {
            await MainActor.run {
                self.userProfile = profile
                self.isLoading = false
            }
        } else {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    func updateUserName(uid: String, newName: String) async throws {
        let db = try requireDB()
        try await db.collection("users").document(uid).updateData([
            "name": newName
        ])
        
        await MainActor.run {
            self.userProfile?.name = newName
        }
    }
    
    func updateDarkMode(uid: String, darkMode: Bool) async throws {
        let db = try requireDB()
        try await db.collection("users").document(uid).updateData([
            "darkMode": darkMode
        ])
        
        await MainActor.run {
            self.userProfile?.darkMode = darkMode
        }
    }
    
    func updateLastLogin(uid: String) async throws {
        let db = try requireDB()
        try await db.collection("users").document(uid).updateData([
            "lastLogin": Timestamp(date: Date())
        ])
    }
    
    func updateQuestionnaireResponses(uid: String, responses: QuestionnaireResponse) async throws {
        var responsesWithTimestamp = responses
        responsesWithTimestamp.updatedAt = Date()
        
        let encoder = Firestore.Encoder()
        let encodedResponses = try encoder.encode(responsesWithTimestamp)

        let db = try requireDB()
        try await db.collection("users").document(uid).updateData([
            "questionnaireResponses": encodedResponses
        ])
        
        let historyEntry = QuestionnaireHistoryEntry(
            financialGoal: responses.financialGoal,
            incomeRange: responses.incomeRange,
            expenses: responses.expenses,
            riskTolerance: responses.riskTolerance,
            savingsExperience: responses.savingsExperience,
            primaryConcerns: responses.primaryConcerns,
            additionalComments: responses.additionalComments,
            timestamp: Date(),
            changeNote: "Updated questionnaire responses"
        )
        
        let historyRef = db.collection("users").document(uid).collection("questionnaireHistory").document(historyEntry.id)
        try historyRef.setData(from: historyEntry)
        
        let updatedResponses = responsesWithTimestamp
        await MainActor.run {
            self.userProfile?.questionnaireResponses = updatedResponses
        }
    }
    
    func fetchQuestionnaireHistory(uid: String) async throws -> [QuestionnaireHistoryEntry] {
        let db = try requireDB()
        let snapshot = try await db.collection("users").document(uid)
            .collection("questionnaireHistory")
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> QuestionnaireHistoryEntry? in
            try? doc.data(as: QuestionnaireHistoryEntry.self)
        }
    }
}
