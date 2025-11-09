import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var isSaving = false
    @State private var showingEditQuestionnaire = false
    
    var body: some View {
        Form {
            Section(header: Text("Profile")) {
                if let profile = firestoreManager.userProfile {
                    if isEditingName {
                        HStack {
                            TextField("Name", text: $editedName)
                            Button("Save") {
                                saveName()
                            }
                            .disabled(editedName.isEmpty || isSaving)
                            Button("Cancel") {
                                isEditingName = false
                                editedName = profile.name
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(profile.name)
                                .foregroundColor(.secondary)
                            Button(action: {
                                editedName = profile.name
                                isEditingName = true
                            }) {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                    
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(profile.email)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Points")
                        Spacer()
                        Text("\(profile.totalPoints)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Currency")
                        Spacer()
                        Text(profile.currency)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Questionnaire")) {
                Button(action: { showingEditQuestionnaire = true }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Update Financial Profile")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let responses = firestoreManager.userProfile?.questionnaireResponses,
                   let updatedAt = responses.updatedAt {
                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(updatedAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
            
            Section(header: Text("Preferences")) {
                Toggle(isOn: Binding(
                    get: { isDarkMode },
                    set: { newValue in
                        isDarkMode = newValue
                        toggleDarkMode(newValue)
                    }
                )) {
                    HStack {
                        Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                        Text("Dark Mode")
                    }
                }
            }
            
            Section(header: Text("Account")) {
                if let profile = firestoreManager.userProfile {
                    HStack {
                        Text("Member Since")
                        Spacer()
                        Text(profile.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Last Login")
                        Spacer()
                        Text(profile.lastLogin, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: {
                    authManager.signOut()
                    firestoreManager.userProfile = nil
                }) {
                    HStack {
                        Text("Sign Out")
                        Spacer()
                        Image(systemName: "arrow.right.square")
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditQuestionnaire) {
            EditQuestionnaireView(currentResponse: firestoreManager.userProfile?.questionnaireResponses)
        }
    }
    
    private func saveName() {
        guard let uid = authManager.user?.uid else { return }
        isSaving = true
        
        Task {
            do {
                try await firestoreManager.updateUserName(uid: uid, newName: editedName)
                await MainActor.run {
                    isEditingName = false
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
    
    private func toggleDarkMode(_ enabled: Bool) {
        guard let uid = authManager.user?.uid else { return }
        
        Task {
            try? await firestoreManager.updateDarkMode(uid: uid, darkMode: enabled)
        }
    }
}

#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(AuthenticationManager())
            .environmentObject(FirestoreManager())
    }
}
