import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirestoreManager: ObservableObject {
    private let db = Firestore.firestore()
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    
    func createUserProfile(uid: String, name: String, email: String) async throws {
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
            )
        )
        
        try db.collection("users").document(uid).setData(from: newProfile)
        await MainActor.run {
            self.userProfile = newProfile
        }
    }
    
    func fetchUserProfile(uid: String) async throws {
        await MainActor.run {
            self.isLoading = true
        }
        
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
        try await db.collection("users").document(uid).updateData([
            "name": newName
        ])
        
        await MainActor.run {
            self.userProfile?.name = newName
        }
    }
    
    func updateDarkMode(uid: String, darkMode: Bool) async throws {
        try await db.collection("users").document(uid).updateData([
            "darkMode": darkMode
        ])
        
        await MainActor.run {
            self.userProfile?.darkMode = darkMode
        }
    }
    
    func updateLastLogin(uid: String) async throws {
        try await db.collection("users").document(uid).updateData([
            "lastLogin": Timestamp(date: Date())
        ])
    }
}
