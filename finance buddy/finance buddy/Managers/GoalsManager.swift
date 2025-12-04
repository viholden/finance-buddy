import Foundation
import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

class GoalsManager: ObservableObject {
    private var db: Firestore?
    @Published var goals: [Goal] = []
    @Published var isLoading = false

    init() {
        if FirebaseApp.app() != nil {
            self.db = Firestore.firestore()
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(setupFirestoreIfNeeded), name: UIApplication.didFinishLaunchingNotification, object: nil)
        }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func setupFirestoreIfNeeded() {
        if FirebaseApp.app() != nil { self.db = Firestore.firestore(); NotificationCenter.default.removeObserver(self) }
    }

    private func requireDB() throws -> Firestore {
        if let db = self.db { return db }
        throw NSError(domain: "GoalsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Firebase is not configured."])
    }
    
    func fetchGoals(uid: String) async throws {
        await MainActor.run { self.isLoading = true }
        
        let db = try requireDB()
        let snapshot = try await db.collection("users").document(uid).collection("goals").getDocuments()
        
        let fetchedGoals = snapshot.documents.compactMap { doc -> Goal? in
            try? doc.data(as: Goal.self)
        }
        
        await MainActor.run {
            self.goals = fetchedGoals
            self.isLoading = false
        }
    }
    
    func addGoal(uid: String, goal: Goal) async throws {
        let db = try requireDB()
        let docRef = db.collection("users").document(uid).collection("goals").document(goal.id)
        try docRef.setData(from: goal)
        
        await MainActor.run {
            self.goals.append(goal)
        }
    }
    
    func updateGoal(uid: String, goal: Goal) async throws {
        let db = try requireDB()
        let docRef = db.collection("users").document(uid).collection("goals").document(goal.id)
        try docRef.setData(from: goal)
        
        await MainActor.run {
            if let index = self.goals.firstIndex(where: { $0.id == goal.id }) {
                self.goals[index] = goal
            }
        }
    }
    
    func deleteGoal(uid: String, goalId: String) async throws {
        let db = try requireDB()
        try await db.collection("users").document(uid).collection("goals").document(goalId).delete()
        
        await MainActor.run {
            self.goals.removeAll { $0.id == goalId }
        }
    }
}
