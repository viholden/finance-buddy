import Foundation
import UIKit
import FirebaseCore
import FirebaseFirestore

class ChallengesManager: ObservableObject {
    private var db: Firestore?
    @Published var challenges: [Challenge] = []
    @Published var isLoading = false

    init() {
        if FirebaseApp.app() != nil { self.db = Firestore.firestore() }
        else { NotificationCenter.default.addObserver(self, selector: #selector(setupFirestoreIfNeeded), name: UIApplication.didFinishLaunchingNotification, object: nil) }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func setupFirestoreIfNeeded() { if FirebaseApp.app() != nil { self.db = Firestore.firestore(); NotificationCenter.default.removeObserver(self) } }

    private func requireDB() throws -> Firestore { if let db = self.db { return db }; throw NSError(domain: "ChallengesManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Firebase is not configured."]) }
    
    func fetchChallenges(uid: String) async throws {
        await MainActor.run { self.isLoading = true }
        
        let db = try requireDB()
        let snapshot = try await db.collection("users").document(uid).collection("challenges")
            .order(by: "startDate", descending: true)
            .getDocuments()
        
        let fetchedChallenges = snapshot.documents.compactMap { doc -> Challenge? in
            try? doc.data(as: Challenge.self)
        }
        
        await MainActor.run {
            self.challenges = fetchedChallenges
            self.isLoading = false
        }
    }
    
    func addChallenge(uid: String, challenge: Challenge) async throws {
        let db = try requireDB()
        let docRef = db.collection("users").document(uid).collection("challenges").document(challenge.id)
        try docRef.setData(from: challenge)
        
        await MainActor.run {
            self.challenges.insert(challenge, at: 0)
        }
    }
    
    func updateChallenge(uid: String, challenge: Challenge) async throws {
        let db = try requireDB()
        let docRef = db.collection("users").document(uid).collection("challenges").document(challenge.id)
        try docRef.setData(from: challenge)
        
        await MainActor.run {
            if let index = self.challenges.firstIndex(where: { $0.id == challenge.id }) {
                self.challenges[index] = challenge
            }
        }
    }
    
    func completeChallenge(uid: String, challengeId: String, firestoreManager: FirestoreManager) async throws {
        guard let challenge = challenges.first(where: { $0.id == challengeId }) else { return }
        
        var updatedChallenge = challenge
        updatedChallenge.status = .completed
        updatedChallenge.progressPercent = 100
        
        try await updateChallenge(uid: uid, challenge: updatedChallenge)
        
        let db = try requireDB()
        try await db.collection("users").document(uid).updateData([
            "totalPoints": FieldValue.increment(Int64(challenge.pointsAwarded))
        ])
        
        if firestoreManager.userProfile != nil {
            await MainActor.run {
                firestoreManager.userProfile?.totalPoints += challenge.pointsAwarded
            }
        }
    }
}
