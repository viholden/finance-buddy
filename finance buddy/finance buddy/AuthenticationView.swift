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
    @State private var showingQuestionnaire = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.65, blue: 0.45),
                    Color(red: 0.25, green: 0.75, blue: 0.55),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Logo/Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 100, height: 100)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                }
                
                VStack(spacing: 8) {
                    Text("Finance Buddy")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(isSignUpMode ? "Create Your Account" : "Welcome Back")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                // Form card
                VStack(spacing: 20) {
                    if isSignUpMode {
                        CustomTextField(
                            icon: "person.fill",
                            placeholder: "Full Name",
                            text: $name
                        )
                    }
                    
                    CustomTextField(
                        icon: "envelope.fill",
                        placeholder: "Email",
                        text: $email,
                        keyboardType: .emailAddress
                    )
                    
                    CustomSecureField(
                        icon: "lock.fill",
                        placeholder: "Password",
                        text: $password
                    )
                    
                    if !authManager.errorMessage.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(authManager.errorMessage)
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal)
                    }
                    
                    Button(action: {
                        handleAuthentication()
                    }) {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(isSignUpMode ? "Continue to Questions" : "Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.65, blue: 0.45),
                                    Color(red: 0.25, green: 0.75, blue: 0.55)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(color: Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled((isSignUpMode && name.isEmpty) || email.isEmpty || password.isEmpty || isLoading)
                    .opacity((isSignUpMode && name.isEmpty) || email.isEmpty || password.isEmpty || isLoading ? 0.6 : 1.0)
                    
                    Button(action: {
                        withAnimation {
                            isSignUpMode.toggle()
                            authManager.errorMessage = ""
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(isSignUpMode ? "Already have an account?" : "Don't have an account?")
                                .foregroundColor(.secondary)
                            Text(isSignUpMode ? "Sign In" : "Sign Up")
                                .fontWeight(.semibold)
                                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                        }
                        .font(.subheadline)
                    }
                }
                .padding(30)
                .background(Color.white)
                .cornerRadius(25)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 30)
                
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showingQuestionnaire) {
            QuestionnaireView(
                email: email,
                password: password,
                name: name,
                onComplete: { questionnaireResponse in
                    completeSignUp(with: questionnaireResponse)
                }
            )
        }
    }
    
    private func handleAuthentication() {
        if isSignUpMode {
            showingQuestionnaire = true
        } else {
            isLoading = true
            Task {
                await authManager.signIn(email: email, password: password, firestoreManager: firestoreManager)
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func completeSignUp(with questionnaireResponse: QuestionnaireResponse) {
        isLoading = true
        
        Task {
            await authManager.signUp(
                email: email,
                password: password,
                name: name,
                firestoreManager: firestoreManager,
                questionnaireResponses: questionnaireResponse
            )
            
            await MainActor.run {
                isLoading = false
                showingQuestionnaire = false
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationManager())
}

// MARK: - Custom Components

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                .frame(width: 20)
            
            SecureField(placeholder, text: $text)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
