import SwiftUI

struct AIAdvisorChatView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @StateObject private var aiManager = AIAdvisorManager()
    @StateObject private var expensesManager = ExpensesManager()
    @StateObject private var goalsManager = GoalsManager()
    
    @State private var newMessage = ""
    @State private var showingClearConfirmation = false
    
    var chatHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.15, green: 0.65, blue: 0.45), Color(red: 0.25, green: 0.75, blue: 0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            Text("AI Financial Advisor")
                .font(.headline)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(red: 0.2, green: 0.7, blue: 0.5))
                    .frame(width: 8, height: 8)
                Text("Online")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
    
    var welcomeMessage: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 50))
                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
            
            Text("Welcome to AI Financial Advisor")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("I'm here to help with your financial questions. I'll learn from your spending habits, goals, and preferences to provide personalized advice.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 40)
    }
    
    @ViewBuilder
    var errorView: some View {
        if let error = aiManager.errorMessage {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                Text(error)
                    .font(.caption)
            }
            .foregroundColor(.red)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if aiManager.messages.isEmpty {
                        welcomeMessage
                    } else {
                        ForEach(aiManager.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        
                        if aiManager.isLoading {
                            TypingIndicator()
                        }
                    }
                    
                    errorView
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: aiManager.messages.count) { oldValue, newValue in
                if let lastMessage = aiManager.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    var quickSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                SuggestionChip(text: "Budget help", icon: "chart.pie.fill") {
                    newMessage = "How do I create a budget?"
                    sendMessage()
                }
                SuggestionChip(text: "Investment tips", icon: "chart.line.uptrend.xyaxis") {
                    newMessage = "How do I start investing?"
                    sendMessage()
                }
                SuggestionChip(text: "Save money", icon: "banknote.fill") {
                    newMessage = "How can I save more money?"
                    sendMessage()
                }
                SuggestionChip(text: "Reduce debt", icon: "creditcard.fill") {
                    newMessage = "How do I pay off my debt?"
                    sendMessage()
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    var inputArea: some View {
        HStack(spacing: 12) {
            HStack {
                TextField("Ask me anything...", text: $newMessage)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                
                Button(action: {}) {
                    Image(systemName: "paperclip")
                        .foregroundColor(.secondary)
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(20)
            
            Button(action: sendMessage) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.7, blue: 0.5))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .disabled(newMessage.isEmpty)
            .opacity(newMessage.isEmpty ? 0.5 : 1.0)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            messagesScrollView
            quickSuggestions
            inputArea
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingClearConfirmation = true }) {
                        Label("Clear History", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                }
            }
        }
        .alert("Clear Chat History?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await aiManager.clearHistory()
                }
            }
        } message: {
            Text("This will permanently delete all messages in this conversation.")
        }
        .onAppear {
            // Refresh context every time they come back to AI Advisor
            Task {
                if let uid = authManager.user?.uid {
                    try? await expensesManager.fetchExpenses(uid: uid)
                    try? await goalsManager.fetchGoals(uid: uid)
                    
                    // Update AI with FRESH user context
                    aiManager.updateUserContext(
                        profile: firestoreManager.userProfile,
                        expenses: expensesManager.expenses,
                        goals: goalsManager.goals,
                        questionnaire: firestoreManager.userProfile?.questionnaireResponses,
                        uid: uid
                    )
                }
            }
        }
        .task {
            // Initial load when view first appears
            if let uid = authManager.user?.uid {
                try? await expensesManager.fetchExpenses(uid: uid)
                try? await goalsManager.fetchGoals(uid: uid)
                
                // Update AI with user context and load chat history
                aiManager.updateUserContext(
                    profile: firestoreManager.userProfile,
                    expenses: expensesManager.expenses,
                    goals: goalsManager.goals,
                    questionnaire: firestoreManager.userProfile?.questionnaireResponses,
                    uid: uid
                )
            }
        }
        .onChange(of: expensesManager.expenses) { oldValue, newValue in
            // Update AI context when expenses change
            aiManager.updateUserContext(
                profile: firestoreManager.userProfile,
                expenses: newValue,
                goals: goalsManager.goals,
                questionnaire: firestoreManager.userProfile?.questionnaireResponses,
                uid: authManager.user?.uid
            )
        }
        .onChange(of: goalsManager.goals) { oldValue, newValue in
            // Update AI context when goals change
            aiManager.updateUserContext(
                profile: firestoreManager.userProfile,
                expenses: expensesManager.expenses,
                goals: newValue,
                questionnaire: firestoreManager.userProfile?.questionnaireResponses,
                uid: authManager.user?.uid
            )
        }
    }
    
    func sendMessage() {
        guard !newMessage.isEmpty else { return }
        let message = newMessage
        newMessage = ""
        
        Task {
            await aiManager.sendMessage(message)
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(message.isUser ?
                               Color(red: 0.2, green: 0.7, blue: 0.5) :
                               Color(.systemGray5))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(20)
                
                Text(timeString(from: message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser { Spacer() }
        }
    }
    
    func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TypingIndicator: View {
    @State private var numberOfDots = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .opacity(numberOfDots > index ? 1 : 0.3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .cornerRadius(20)
            
            Spacer()
        }
        .onReceive(timer) { _ in
            numberOfDots = (numberOfDots + 1) % 4
        }
    }
}

struct SuggestionChip: View {
    let text: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(text)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.15))
            .foregroundColor(Color(red: 0.15, green: 0.6, blue: 0.4))
            .cornerRadius(16)
        }
    }
}
