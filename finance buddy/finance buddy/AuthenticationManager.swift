//
//  AuthenticationManager.swift
//  finance buddy
//
//  Created by Hannah Holden on 10/6/25.
//

import Foundation
import FirebaseAuth

class AuthenticationManager: ObservableObject {
    @Published var user: User?
    @Published var errorMessage: String = ""
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        self.user = Auth.auth().currentUser
        
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    func signUp(email: String, password: String, name: String, firestoreManager: FirestoreManager) async {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            try await firestoreManager.createUserProfile(uid: result.user.uid, name: name, email: email)
            await MainActor.run {
                self.user = result.user
                self.errorMessage = ""
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func signIn(email: String, password: String, firestoreManager: FirestoreManager) async {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            try await firestoreManager.fetchUserProfile(uid: result.user.uid)
            try await firestoreManager.updateLastLogin(uid: result.user.uid)
            await MainActor.run {
                self.user = result.user
                self.errorMessage = ""
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.errorMessage = ""
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
