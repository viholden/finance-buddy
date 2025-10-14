import Foundation
import FirebaseFirestore

class ChallengesManager: ObservableObject {
    private let db = Firestore.firestore()
    @Published var challenges: [Challenge] = []
    @Published var isLoading = false
    
    func fetchChallenges(uid: String) async throws {
        await MainActor.run { self.isLoading = true }
        
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
        let docRef = db.collection("users").document(uid).collection("challenges").document(challenge.id)
        try docRef.setData(from: challenge)
        
        await MainActor.run {
            self.challenges.insert(challenge, at: 0)
        }
    }
    
    func updateChallenge(uid: String, challenge: Challenge) async throws {
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
