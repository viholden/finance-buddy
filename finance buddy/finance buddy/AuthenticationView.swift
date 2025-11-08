//
//  AuthenticationView.swift
//  finance buddy
//
//  Created by Hannah Holden on 10/6/25.
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isSignUpMode = false
    @State private var isLoading = false
    @State private var showQuestionnaire = false
    @State private var questionnaireResponse: QuestionnaireResponse?
    
    var body: some View {
        if showQuestionnaire {
            QuestionnaireView(
                email: email,
                password: password,
                name: name,
                onComplete: { response in
                    questionnaireResponse = response
                    completeSignUp()
                }
            )
        } else {
            VStack(spacing: 20) {
                Spacer()
                
                Text("Finance Buddy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(isSignUpMode ? "Create Account" : "Welcome Back")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isSignUpMode {
                    TextField("Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocorrectionDisabled()
                        .padding(.horizontal)
                }
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding(.horizontal)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                if !authManager.errorMessage.isEmpty {
                    Text(authManager.errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    handleAuthentication()
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text(isSignUpMode ? "Next" : "Sign In")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled((isSignUpMode && name.isEmpty) || email.isEmpty || password.isEmpty || isLoading)
                
                Button(action: {
                    isSignUpMode.toggle()
                    authManager.errorMessage = ""
                }) {
                    Text(isSignUpMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func handleAuthentication() {
        isLoading = true
        
        if isSignUpMode {
            // Show questionnaire before signing up
            showQuestionnaire = true
            isLoading = false
        } else {
            // Sign in directly
            Task {
                await authManager.signIn(email: email, password: password, firestoreManager: firestoreManager)
                
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func completeSignUp() {
        Task {
            await authManager.signUp(
                email: email,
                password: password,
                name: name,
                questionnaireResponse: questionnaireResponse ?? QuestionnaireResponse(),
                firestoreManager: firestoreManager
            )
            
            await MainActor.run {
                isLoading = false
                showQuestionnaire = false
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationManager())
}
