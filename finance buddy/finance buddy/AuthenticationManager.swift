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
    
    init() {
        self.user = Auth.auth().currentUser
        
        // Listen for authentication state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }
    
    // Sign up with email and password
    func signUp(email: String, password: String) async {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
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
    
    // Sign in with email and password
    func signIn(email: String, password: String) async {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
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
    
    // Sign out
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
