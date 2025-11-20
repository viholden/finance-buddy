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
        ScrollView {
            VStack(spacing: 24) {
                // Header Card
                if let profile = firestoreManager.userProfile {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.15, green: 0.65, blue: 0.45), Color(red: 0.25, green: 0.75, blue: 0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 90, height: 90)
                                
                                Text(String(profile.name.prefix(1)).uppercased())
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                            }
                            
                            VStack(spacing: 4) {
                                if isEditingName {
                                    HStack {
                                        TextField("Name", text: $editedName)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(maxWidth: 200)
                                        
                                        Button(action: saveName) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.white)
                                        }
                                        .disabled(editedName.isEmpty || isSaving)
                                        
                                        Button(action: {
                                            isEditingName = false
                                            editedName = profile.name
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    }
                                } else {
                                    HStack(spacing: 8) {
                                        Text(profile.name)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Button(action: {
                                            editedName = profile.name
                                            isEditingName = true
                                        }) {
                                            Image(systemName: "pencil.circle.fill")
                                                .foregroundColor(.white.opacity(0.9))
                                        }
                                    }
                                }
                                
                                Text(profile.email)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            HStack(spacing: 20) {
                                VStack(spacing: 4) {
                                    Text("\(profile.totalPoints)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text("Points")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                                
                                VStack(spacing: 4) {
                                    Text(profile.currency)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text("Currency")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                            }
                        }
                        .padding(24)
                    }
                    .frame(height: 300)
                    .padding(.horizontal)
                }
                
                // Financial Profile Section
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                        Text("Financial Profile")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    Button(action: { showingEditQuestionnaire = true }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.2))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "square.and.pencil")
                                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Update Financial Profile")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if let responses = firestoreManager.userProfile?.questionnaireResponses,
                                   let updatedAt = responses.updatedAt {
                                    Text("Last updated: \(formatDate(updatedAt))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                }
                
                // Settings Section
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                        Text("Settings")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        Toggle(isOn: $isDarkMode) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                                }
                                
                                Text("Dark Mode")
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                }
                
                // Sign Out Button
                Button(action: {
                    authManager.signOut()
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.red)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.red, lineWidth: 2)
                    )
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(AuthenticationManager())
            .environmentObject(FirestoreManager())
    }
}
