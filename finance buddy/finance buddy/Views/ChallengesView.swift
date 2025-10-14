import SwiftUI

struct ChallengesView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @StateObject private var challengesManager = ChallengesManager()
    @State private var showingAddChallenge = false
    
    var activeChallenges: [Challenge] {
        challengesManager.challenges.filter { $0.status == .active }
    }
    
    var completedChallenges: [Challenge] {
        challengesManager.challenges.filter { $0.status == .completed }
    }
    
    var body: some View {
        ZStack {
            if challengesManager.isLoading {
                ProgressView()
            } else if challengesManager.challenges.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "trophy")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No Challenges Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Start a challenge to earn points")
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    if !activeChallenges.isEmpty {
                        Section(header: Text("Active Challenges")) {
                            ForEach(activeChallenges) { challenge in
                                NavigationLink(destination: ChallengeDetailView(challengesManager: challengesManager, challenge: challenge)) {
                                    ChallengeRowView(challenge: challenge)
                                }
                            }
                        }
                    }
                    
                    if !completedChallenges.isEmpty {
                        Section(header: Text("Completed")) {
                            ForEach(completedChallenges) { challenge in
                                ChallengeRowView(challenge: challenge)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Challenges")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddChallenge = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddChallenge) {
            AddChallengeView(challengesManager: challengesManager)
        }
        .task {
            if let uid = authManager.user?.uid {
                try? await challengesManager.fetchChallenges(uid: uid)
            }
        }
    }
}

struct ChallengeRowView: View {
    let challenge: Challenge
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: challenge.status == .completed ? "trophy.fill" : "flag.fill")
                    .foregroundColor(challenge.status == .completed ? .orange : .blue)
                
                Text(challenge.name)
                    .font(.headline)
                
                Spacer()
                
                if challenge.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            Text(challenge.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if challenge.status == .active {
                ProgressView(value: challenge.progressPercent, total: 100)
                    .tint(.blue)
                
                HStack {
                    Text("\(Int(challenge.progressPercent))% Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Label("\(challenge.pointsAwarded) pts", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            HStack {
                Text(challenge.startDate, style: .date)
                Text("-")
                Text(challenge.endDate, style: .date)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct AddChallengeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var challengesManager: ChallengesManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var targetAmount = ""
    @State private var pointsAwarded = "100"
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400 * 7)
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Challenge Details")) {
                    TextField("Challenge Name", text: $name)
                    TextField("Description", text: $description)
                    TextField("Target Amount (optional)", text: $targetAmount)
                        .keyboardType(.decimalPad)
                    TextField("Points Awarded", text: $pointsAwarded)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Duration")) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle("New Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createChallenge()
                    }
                    .disabled(name.isEmpty || description.isEmpty)
                }
            }
        }
    }
    
    private func createChallenge() {
        guard let uid = authManager.user?.uid,
              let points = Int(pointsAwarded) else { return }
        
        let target = Double(targetAmount)
        
        let challenge = Challenge(
            name: name,
            description: description,
            status: .active,
            startDate: startDate,
            endDate: endDate,
            pointsAwarded: points,
            targetAmount: target,
            currentAmount: 0,
            progressPercent: 0
        )
        
        Task {
            try? await challengesManager.addChallenge(uid: uid, challenge: challenge)
            await MainActor.run { dismiss() }
        }
    }
}

struct ChallengeDetailView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @ObservedObject var challengesManager: ChallengesManager
    @State var challenge: Challenge
    @State private var showingCompletion = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "flag.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        Text(challenge.name)
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    
                    Text(challenge.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 20)
                            .frame(width: 150, height: 150)
                        
                        Circle()
                            .trim(from: 0, to: challenge.progressPercent / 100)
                            .stroke(Color.blue, lineWidth: 20)
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(challenge.progressPercent))%")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    
                    if let target = challenge.targetAmount, let current = challenge.currentAmount {
                        Text("$\(current, specifier: "%.2f") / $\(target, specifier: "%.2f")")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Reward")
                        Spacer()
                        Label("\(challenge.pointsAwarded) points", systemImage: "star.fill")
                            .foregroundColor(.orange)
                    }
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text("\(challenge.startDate, style: .date) - \(challenge.endDate, style: .date)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(challenge.status.rawValue.capitalized)
                            .foregroundColor(challenge.status == .completed ? .green : .blue)
                    }
                }
                
                if challenge.status == .active {
                    Button(action: {
                        completeChallenge()
                    }) {
                        Text("Complete Challenge")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Challenge Complete!", isPresented: $showingCompletion) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You earned \(challenge.pointsAwarded) points! 🎉")
        }
    }
    
    private func completeChallenge() {
        guard let uid = authManager.user?.uid else { return }
        
        Task {
            try? await challengesManager.completeChallenge(uid: uid, challengeId: challenge.id, firestoreManager: firestoreManager)
            await MainActor.run {
                challenge.status = .completed
                showingCompletion = true
            }
        }
    }
}
