import Foundation
import FirebaseFirestore
import FirebaseAuth

class GoalsManager: ObservableObject {
    private let db = Firestore.firestore()
    @Published var goals: [Goal] = []
    @Published var isLoading = false
    
    func fetchGoals(uid: String) async throws {
        await MainActor.run { self.isLoading = true }
        
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
        let docRef = db.collection("users").document(uid).collection("goals").document(goal.id)
        try docRef.setData(from: goal)
        
        await MainActor.run {
            self.goals.append(goal)
        }
    }
    
    func updateGoal(uid: String, goal: Goal) async throws {
        let docRef = db.collection("users").document(uid).collection("goals").document(goal.id)
        try docRef.setData(from: goal)
        
        await MainActor.run {
            if let index = self.goals.firstIndex(where: { $0.id == goal.id }) {
                self.goals[index] = goal
            }
        }
    }
    
    func deleteGoal(uid: String, goalId: String) async throws {
        try await db.collection("users").document(uid).collection("goals").document(goalId).delete()
        
        await MainActor.run {
            self.goals.removeAll { $0.id == goalId }
        }
    }
}
