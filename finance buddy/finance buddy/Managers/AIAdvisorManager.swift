import Foundation
import Combine
import FirebaseFirestore

class AIAdvisorManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Using LM Studio local server - 100% FREE, runs on your Mac!
    // Download LM Studio: https://lmstudio.ai
    // Model: Phi-3 Mini 4K Instruct (3.8B params, fast & smart)
    private let apiURL = "http://127.0.0.1:1234/v1/chat/completions"
    private let modelName = "phi-3-mini-4k-instruct"
    private var cancellables = Set<AnyCancellable>()
    
    // Store user context - updates in real-time
    private var userProfile: UserProfile?
    private var recentExpenses: [Expense] = []
    private var activeGoals: [Goal] = []
    private var questionnaireResponses: QuestionnaireResponse?
    private var userUID: String?
    
    // AI-derived insights (generated and stored)
    private var userInsights: [String: Any] = [:]
    
    // Firestore for persistent chat history and insights
    private let db = Firestore.firestore()
    
    func updateUserContext(
        profile: UserProfile?,
        expenses: [Expense],
        goals: [Goal],
        questionnaire: QuestionnaireResponse?,
        uid: String?
    ) {
        self.userProfile = profile
        self.recentExpenses = expenses
        self.activeGoals = goals
        self.questionnaireResponses = questionnaire
        self.userUID = uid
        
        // Load chat history and insights from Firebase when user context is set
        if let uid = uid {
            Task {
                await loadChatHistory(uid: uid)
                await loadUserInsights(uid: uid)
                await generateAndStoreInsights(uid: uid)
            }
        }
    }
    
    // Load persistent chat history from Firebase
    private func loadChatHistory(uid: String) async {
        do {
            print("🔍 [AI] Loading chat history for user: \(uid)")
            let snapshot = try await db.collection("users").document(uid)
                .collection("aiChatHistory")
                .order(by: "timestamp", descending: false)
                .limit(to: 50) // Load last 50 messages
                .getDocuments()
            
            let loadedMessages = snapshot.documents.compactMap { doc -> ChatMessage? in
                let data = doc.data()
                guard let text = data["text"] as? String,
                      let isUser = data["isUser"] as? Bool,
                      let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                return ChatMessage(id: doc.documentID, text: text, isUser: isUser, timestamp: timestamp)
            }
            
            print("✅ [AI] Loaded \(loadedMessages.count) messages from Firebase")
            await MainActor.run {
                self.messages = loadedMessages
            }
        } catch {
            print("❌ [AI] Error loading chat history: \(error)")
            print("   This might be a Firebase rules issue - check aiChatHistory permissions")
        }
    }
    
    // Save message to Firebase for persistence
    private func saveChatMessage(_ message: ChatMessage, uid: String) async {
        do {
            print("💾 [AI] Saving message to Firebase: \(message.text.prefix(50))...")
            try await db.collection("users").document(uid)
                .collection("aiChatHistory")
                .document(message.id)
                .setData([
                    "text": message.text,
                    "isUser": message.isUser,
                    "timestamp": Timestamp(date: message.timestamp)
                ])
            
            print("✅ [AI] Message saved successfully")
            // After saving, regenerate insights (learns from every interaction)
            await generateAndStoreInsights(uid: uid)
        } catch {
            print("❌ [AI] Error saving chat message: \(error)")
            print("   Check Firebase rules for aiChatHistory subcollection")
        }
    }
    
    // Load AI-generated insights about the user
    private func loadUserInsights(uid: String) async {
        do {
            print("🔍 [AI] Loading user insights for: \(uid)")
            let doc = try await db.collection("users").document(uid)
                .collection("aiInsights")
                .document("profile")
                .getDocument()
            
            if let data = doc.data() {
                print("✅ [AI] Loaded \(data.keys.count) insights: \(data.keys.joined(separator: ", "))")
                await MainActor.run {
                    self.userInsights = data
                }
            } else {
                print("⚠️ [AI] No insights found - will generate on first message")
            }
        } catch {
            print("❌ [AI] Error loading insights: \(error)")
            print("   Check Firebase rules for aiInsights subcollection")
        }
    }
    
    // Generate and store behavioral insights (the AI "learns" about the user)
    private func generateAndStoreInsights(uid: String) async {
        var insights: [String: Any] = [:]
        
        // SPENDING PATTERNS
        if !recentExpenses.isEmpty {
            let categories = Dictionary(grouping: recentExpenses, by: { $0.category })
            let total = recentExpenses.reduce(0.0) { $0 + $1.amount }
            let avgPerTransaction = total / Double(recentExpenses.count)
            
            if let topCategory = categories.max(by: { $0.value.count < $1.value.count }) {
                insights["topSpendingCategory"] = topCategory.key
                let categoryTotal = topCategory.value.reduce(0.0) { $0 + $1.amount }
                insights["topCategoryAmount"] = categoryTotal
            }
            
            insights["averageTransactionAmount"] = avgPerTransaction
            insights["totalTransactions"] = recentExpenses.count
            insights["spendingFrequency"] = recentExpenses.count > 20 ? "high" : recentExpenses.count > 10 ? "moderate" : "low"
            
            // Detect overspending patterns
            var overspendingAreas: [String] = []
            for (category, expenses) in categories {
                let categoryTotal = expenses.reduce(0.0) { $0 + $1.amount }
                if categoryTotal > total * 0.3 { // Spending >30% in one category
                    overspendingAreas.append(category)
                }
            }
            insights["overspendingAreas"] = overspendingAreas
        }
        
        // GOAL PROGRESS PATTERNS
        if !activeGoals.isEmpty {
            let goalsWithProgress = activeGoals.filter { $0.currentAmount > 0 }
            let avgProgress = activeGoals.reduce(0.0) { $0 + ($1.targetAmount > 0 ? $1.currentAmount / $1.targetAmount : 0) } / Double(activeGoals.count)
            
            insights["activeGoalsCount"] = activeGoals.count
            insights["averageGoalProgress"] = avgProgress
            insights["goalDiscipline"] = avgProgress > 0.5 ? "strong" : avgProgress > 0.2 ? "moderate" : "needs improvement"
            
            let completedGoalsCount = activeGoals.filter { $0.currentAmount >= $0.targetAmount }.count
            insights["completedGoals"] = completedGoalsCount
        }
        
        // CONVERSATION INSIGHTS
        let userMessages = messages.filter { $0.isUser }
        if userMessages.count >= 5 {
            insights["engagementLevel"] = "highly engaged"
            insights["totalConversations"] = userMessages.count
            
            // Topics they care about
            var topicsDiscussed: [String] = []
            let allText = userMessages.map { $0.text.lowercased() }.joined(separator: " ")
            if allText.contains("debt") || allText.contains("loan") { topicsDiscussed.append("debt management") }
            if allText.contains("invest") || allText.contains("stock") { topicsDiscussed.append("investing") }
            if allText.contains("budget") { topicsDiscussed.append("budgeting") }
            if allText.contains("save") || allText.contains("saving") { topicsDiscussed.append("saving") }
            if allText.contains("emergency") { topicsDiscussed.append("emergency fund") }
            if allText.contains("retire") { topicsDiscussed.append("retirement") }
            
            insights["primaryInterests"] = topicsDiscussed
        } else {
            insights["engagementLevel"] = "new user"
        }
        
        // BEHAVIORAL PROFILE
        if let responses = questionnaireResponses {
            if let risk = responses.riskTolerance {
                insights["riskProfile"] = risk
            }
            if let experience = responses.savingsExperience {
                insights["experienceLevel"] = experience
            }
        }
        
        insights["lastUpdated"] = Timestamp(date: Date())
        
        // Store insights in Firebase
        do {
            try await db.collection("users").document(uid)
                .collection("aiInsights")
                .document("profile")
                .setData(insights, merge: true)
            
            await MainActor.run {
                self.userInsights = insights
            }
        } catch {
            print("Error storing insights: \(error)")
        }
    }
    
    func sendMessage(_ text: String) async {
        let userMessage = ChatMessage(text: text, isUser: true, timestamp: Date())
        
        await MainActor.run {
            messages.append(userMessage)
            isLoading = true
            errorMessage = nil
        }
        
        // Save user message to Firebase
        if let uid = userUID {
            await saveChatMessage(userMessage, uid: uid)
        }
        
        do {
            let response = try await generateResponse(for: text)
            let aiMessage = ChatMessage(text: response, isUser: false, timestamp: Date())
            
            await MainActor.run {
                messages.append(aiMessage)
                isLoading = false
            }
            
            // Save AI response to Firebase
            if let uid = userUID {
                await saveChatMessage(aiMessage, uid: uid)
            }
        } catch {
            await MainActor.run {
                let errorDesc = error.localizedDescription
                // Check if LM Studio is not running
                if errorDesc.contains("Connection refused") || errorDesc.contains("could not connect") {
                    errorMessage = "LM Studio not running. Please start LM Studio and enable the local server."
                } else {
                    errorMessage = "Failed to get response: \(errorDesc)"
                }
                isLoading = false
            }
        }
    }
    
    private func generateResponse(for userInput: String) async throws -> String {
        // 🔥 RULES ENGINE - Check if question triggers hard-coded financial wisdom
        if let ruleBasedAnswer = applyFinancialRules(to: userInput) {
            return ruleBasedAnswer
        }
        
        // Try Phi-3 model first, fallback to rule-based if it fails
        do {
            return try await generateResponseFromPhi3(for: userInput)
        } catch {
            print("⚠️ Phi-3 failed, using fallback: \(error)")
            return generateSmartResponse(for: userInput)
        }
    }
    
    // 🔥 FINANCIAL RULES ENGINE - Hard-coded financial wisdom for accuracy
    private func applyFinancialRules(to question: String) -> String? {
        let q = question.lowercased()
        
        // EMERGENCY FUND RULES
        if q.contains("emergency fund") && (q.contains("how much") || q.contains("size") || q.contains("should")) {
            let income = extractIncome(from: questionnaireResponses)
            if let income = income {
                let min = Int(income * 4)
                let max = Int(income * 6)
                return "💡 **Financial Rule:** Emergency funds should cover 3-6 months of expenses. Based on your income, aim for $\(min) to $\(max). Start with $500-1000 and build from there. Keep it in a high-yield savings account for easy access."
            } else {
                return "💡 **Financial Rule:** Emergency funds should cover 3-6 months of expenses. Start with $500-1000 and build from there. Keep it in a high-yield savings account for easy access."
            }
        }
        
        // DEBT PAYOFF STRATEGY
        if q.contains("debt") && (q.contains("pay") || q.contains("strategy") || q.contains("first")) {
            return "💡 **Financial Rule:** Use the Debt Avalanche method - pay minimums on all debts, then put extra money toward the HIGHEST interest rate debt first. This saves you the most money. (Alternative: Debt Snowball targets smallest balance first for motivation.)"
        }
        
        // HIGH INTEREST DEBT PRIORITY
        if (q.contains("credit card") && q.contains("debt")) || (q.contains("high interest")) {
            return "💡 **Financial Rule:** High-interest debt (>10% APR) is your #1 priority. Pay minimums everywhere else, attack this first. Every dollar here saves you more than investing would earn. Consider balance transfers to 0% APR cards."
        }
        
        // EMPLOYER MATCH (401k)
        if (q.contains("401k") || q.contains("401(k)")) && q.contains("match") {
            return "💡 **Financial Rule:** ALWAYS contribute enough to get full employer match - it's free money! This is a 100% instant return. Do this BEFORE paying extra on low-interest debt or investing elsewhere."
        }
        
        // HOUSING COST RULE
        if q.contains("rent") || q.contains("housing") || q.contains("mortgage") {
            if q.contains("how much") || q.contains("afford") || q.contains("should") {
                let income = extractIncome(from: questionnaireResponses)
                let maxHousing = income.map { Int($0 * 0.3) }
                return "💡 **Financial Rule:** Housing should be ≤30% of take-home pay. \(maxHousing.map { "For you, that's around $\($0)/month max." } ?? "") This leaves room for savings, emergencies, and other goals."
            }
        }
        
        // SAVINGS RATE TARGET
        if q.contains("save") && (q.contains("how much") || q.contains("percentage") || q.contains("%")) {
            return "💡 **Financial Rule:** Aim to save 20% of income using the 50/30/20 rule: 50% needs, 30% wants, 20% savings/debt. Start with what you can (even 5-10%) and increase over time."
        }
        
        // INVESTING BASICS (INDEX FUNDS)
        if q.contains("invest") && (q.contains("start") || q.contains("beginner") || q.contains("how")) {
            return "💡 **Financial Rule:** Start with low-cost index funds (like S&P 500). They're diversified, simple, and historically return 10%/year. Open a Roth IRA if you qualify. Invest consistently, ignore short-term volatility."
        }
        
        // RISKY INVESTMENTS (SAFETY CHECK)
        if q.contains("stock pick") || q.contains("day trad") || q.contains("crypto") || q.contains("get rich") {
            return "⚠️ **Safety Check:** Individual stock picking, day trading, and speculative investments are high-risk. 90% of day traders lose money. For most people, index funds and long-term investing are safer and more profitable."
        }
        
        // RETIREMENT SAVINGS
        if q.contains("retire") && (q.contains("how much") || q.contains("save")) {
            return "💡 **Financial Rule:** Save 15% of income for retirement starting in your 20s-30s. Use tax-advantaged accounts: 401(k) → Roth IRA → taxable. The earlier you start, the more compound interest works for you."
        }
        
        return nil // No rule triggered, let AI handle it
    }
    
    // Helper: Extract monthly income from questionnaire
    private func extractIncome(from responses: QuestionnaireResponse?) -> Double? {
        guard let range = responses?.incomeRange else { return nil }
        
        if range.contains("30") && range.contains("50") { return 3300 } // $30-50k = ~$3,300/mo
        if range.contains("50") && range.contains("75") { return 5200 } // $50-75k = ~$5,200/mo
        if range.contains("75") && range.contains("100") { return 7300 } // $75-100k = ~$7,300/mo
        if range.contains("100") { return 10000 } // $100k+ = ~$10,000/mo
        if range.contains("30") { return 2000 } // Under $30k = ~$2,000/mo
        
        return nil
    }
    
    private func generateSmartResponse(for: String) -> String {
        let input = `for`.lowercased()
        let context = buildUserContext()
        
        // Pattern matching for quick, relevant responses
        if input.contains("save") || input.contains("saving") {
            return "💰 Great question about saving! Here are some tips:\n\n• Set up automatic transfers to savings right after payday\n• Try the 50/30/20 rule: 50% needs, 30% wants, 20% savings\n• Start with a small emergency fund ($500-1000)\n• Use apps to round up purchases and save the difference\n\nBased on your profile\(context.isEmpty ? "" : ", you could start by saving just $50/month and build from there!")."
        } else if input.contains("budget") {
            return "📊 Budgeting Tips:\n\n• Track all expenses for 30 days to see patterns\n• Use the envelope method for categories you overspend on\n• Review your budget weekly, not just monthly\n• Be realistic - don't cut everything you enjoy\n\nSmall adjustments work better than drastic changes!"
        } else if input.contains("debt") || input.contains("loan") || input.contains("credit card") {
            return "💳 Managing Debt:\n\n• Pay minimums on everything, then extra on highest interest debt (avalanche method)\n• OR pay off smallest balance first for motivation (snowball method)\n• Call creditors to negotiate lower rates\n• Consider a balance transfer for credit cards\n\nYou've got this! Every payment is progress."
        } else if input.contains("invest") || input.contains("stock") || input.contains("retirement") {
            return "📈 Investment Basics:\n\n• Start with employer 401(k) match (free money!)\n• Open a Roth IRA for tax-free growth\n• Index funds are simple and effective for beginners\n• Invest consistently, not just when markets are up\n\nTime in the market beats timing the market!"
        } else if input.contains("emergency fund") {
            return "🚨 Emergency Fund:\n\n• Target: 3-6 months of expenses\n• Start small: Even $500 makes a difference\n• Keep it in a high-yield savings account\n• Don't touch it unless it's truly an emergency\n\nThis gives you peace of mind and financial stability!"
        } else if input.contains("spend") || input.contains("expense") {
            return "💸 Smart Spending:\n\n• Wait 24 hours before non-essential purchases over $50\n• Unsubscribe from marketing emails to reduce temptation\n• Use cash for discretionary spending\n• Find free alternatives (library, parks, free events)\n\nIt's about being intentional, not depriving yourself!"
        } else if input.contains("goal") {
            return "🎯 Setting Financial Goals:\n\n• Make them SMART: Specific, Measurable, Achievable, Relevant, Time-bound\n• Break big goals into smaller milestones\n• Celebrate progress along the way\n• Adjust as life changes\n\nYour goals should excite you, not stress you out!"
        } else if input.contains("income") || input.contains("earn") || input.contains("raise") {
            return "💼 Increasing Income:\n\n• Ask for a raise (document your accomplishments first)\n• Start a side hustle aligned with your skills\n• Sell items you no longer use\n• Take on freelance projects\n\nEven an extra $200/month makes a big difference!"
        } else if input.contains("thank") || input.contains("thanks") {
            return "You're welcome! I'm here to help you build a strong financial foundation. Feel free to ask anything else! 😊"
        } else if input.contains("hello") || input.contains("hi ") || input.contains("hey") {
            return "Hi there! 👋 I'm your AI Financial Advisor. I can help you with budgeting, saving, debt management, investing, and more. What financial topic would you like to discuss?"
        } else {
            return "I can help you with:\n\n💰 Saving money\n📊 Creating a budget\n💳 Managing debt\n📈 Investing basics\n🚨 Building an emergency fund\n🎯 Setting financial goals\n\nWhat would you like to know more about?"
        }
    }
    
    private func generateResponseFromPhi3(for userInput: String) async throws -> String {
        let context = buildUserContext()
        let conversationInsights = buildConversationInsights()
        let userTone = detectUserTone(userInput)
        let adaptiveToneGuidance = getAdaptiveToneGuidance(for: userTone)
        
        // Phi-3 optimized prompt - HIGHLY personalized with adaptive tone
        let systemPrompt = """
        You are FINANCE BUDDY — \(userProfile?.name ?? "this user")'s personal financial advisor.
        You know them intimately. Reference their specific data to prove you remember everything.
        
        ═══════════════════════════════════════
        COMPLETE USER PROFILE:
        \(context)
        ═══════════════════════════════════════
        
        CONVERSATION HISTORY:
        \(conversationInsights)
        
        USER'S CURRENT EMOTIONAL STATE:
        \(adaptiveToneGuidance)
        
        YOUR MISSION:
        • Give advice ONLY for THEIR situation (not generic tips)
        • Reference their specific goals, spending, and behaviors
        • Use their name naturally
        • Be encouraging about their progress
        • Call out patterns you've noticed ("I see you're spending a lot on...")
        • Match the tone guidance above based on their emotional state
        • 150 token limit - prioritize personalization over length
        • Never start a sentence you can't finish
        """
        
        // Build messages array - include MORE conversation history for context
        var apiMessages: [[String: String]] = []
        
        // Add last 6 messages for richer context
        let conversationHistory = messages.suffix(6).map { message in
            ["role": message.isUser ? "user" : "assistant", "content": message.text]
        }
        apiMessages.append(contentsOf: conversationHistory)
        
        // Add current user message with system prompt on first message
        let isFirstMessage = messages.isEmpty
        let userMessageContent = isFirstMessage ? "\(systemPrompt)\n\nQuestion: \(userInput)" : userInput
        apiMessages.append(["role": "user", "content": userMessageContent])
        
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": apiMessages,
            "temperature": 0.7,
            "max_tokens": 150, // Balanced: fast responses, complete thoughts
            "stream": false
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw AIError.invalidRequest
        }
        
        guard let url = URL(string: apiURL) else {
            throw AIError.invalidRequest
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90 // Increased for first load (model warm-up)
        // No API key needed - LM Studio runs locally!
        
        request.httpBody = jsonData
        
        print("🚀 [AI] Sending request to LM Studio...")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
            print("✅ [AI] Received response from LM Studio")
        } catch let error as NSError where error.code == -1001 {
            print("❌ [AI] LM Studio TIMEOUT - Is the server running?")
            print("   1. Open LM Studio app")
            print("   2. Load Phi-3 Mini model in 'Local Server' tab")
            print("   3. Make sure it's running on port 1234")
            print("   4. Try sending a test message in LM Studio first")
            throw error
        } catch {
            print("❌ [AI] Connection error: \(error.localizedDescription)")
            throw error
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [AI] Invalid response from LM Studio")
            throw AIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorText = String(data: data, encoding: .utf8) {
                print("❌ [AI] LM Studio Error (\(httpResponse.statusCode)): \(errorText)")
            }
            throw AIError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // Parse OpenAI-compatible response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        throw AIError.parsingError
    }
    
    private func formatMessagesForMistral(_ messages: [[String: String]]) -> String {
        var formattedText = "<s>"
        var isFirst = true
        
        for message in messages {
            guard let role = message["role"], let content = message["content"] else { continue }
            
            if role == "system" {
                // System message goes first without INST tags
                formattedText += content + "\n\n"
            } else if role == "user" {
                formattedText += "[INST] \(content) [/INST]"
            } else if role == "assistant" {
                if !isFirst {
                    formattedText += " "
                }
                formattedText += "\(content)</s>"
                isFirst = false
            }
        }
        
        return formattedText
    }
    
    private func buildUserContext() -> String {
        print("\n📊 [AI] Building user context...")
        var context = ""
        
        // USER IDENTITY
        if let profile = userProfile {
            context += "USER: \(profile.name)\n"
            context += "Progress: \(profile.totalPoints) points | Currency: \(profile.currency)\n\n"
            print("   ✓ User profile: \(profile.name)")
        } else {
            print("   ✗ No user profile loaded")
        }
        
        // FINANCIAL PROFILE (from questionnaire)
        if let responses = questionnaireResponses {
            print("   ✓ Questionnaire responses loaded")
            context += "FINANCIAL PROFILE:\n"
            if let goal = responses.financialGoal {
                context += "Primary Goal: \(goal)\n"
            }
            if let income = responses.incomeRange {
                context += "Income: \(income)\n"
            }
            if let risk = responses.riskTolerance {
                context += "Risk Tolerance: \(risk)\n"
            }
            if let experience = responses.savingsExperience {
                context += "Experience: \(experience)\n"
            }
            if let expenses = responses.expenses, !expenses.isEmpty {
                context += "Major Expenses: \(expenses.joined(separator: ", "))\n"
            }
            if let concerns = responses.primaryConcerns, !concerns.isEmpty {
                context += "Concerns: \(concerns.joined(separator: ", "))\n"
            }
            if let comments = responses.additionalComments, !comments.isEmpty {
                context += "Additional: \(comments)\n"
            }
            context += "\n"
        }
        
        // ACTIVE GOALS (what they're working toward) - ENHANCED TRACKING
        if !activeGoals.isEmpty {
            print("   ✓ \(activeGoals.count) active goals loaded")
            context += "ACTIVE GOALS (Dynamic Tracking):\n"
            for goal in activeGoals.prefix(5) {
                let progress = goal.targetAmount > 0 ? (goal.currentAmount / goal.targetAmount) * 100 : 0
                let remaining = goal.targetAmount - goal.currentAmount
                
                // Dynamic status messages
                var status = ""
                if progress >= 100 {
                    status = "🎉 ACHIEVED!"
                } else if progress >= 75 {
                    status = "Almost there! (\(Int(progress))%)"
                } else if progress >= 50 {
                    status = "Halfway! (\(Int(progress))%)"
                } else if progress >= 25 {
                    status = "Good progress (\(Int(progress))%)"
                } else if progress > 0 {
                    status = "Started (\(Int(progress))%)"
                } else {
                    status = "Not started yet"
                }
                
                context += "• \(goal.name): $\(Int(goal.currentAmount))/$\(Int(goal.targetAmount)) - \(status)\n"
                if remaining > 0 && progress < 100 {
                    context += "  → $\(Int(remaining)) remaining\n"
                }
            }
            context += "\n"
        }
        
        // SPENDING BEHAVIOR (actual transaction data)
        if !recentExpenses.isEmpty {
            print("   ✓ \(recentExpenses.count) expenses loaded")
            let totalSpent = recentExpenses.reduce(0.0) { $0 + $1.amount }
            let categories = Dictionary(grouping: recentExpenses, by: { $0.category })
            
            context += "SPENDING PATTERNS:\n"
            context += "Total Recent: $\(String(format: "%.2f", totalSpent)) across \(recentExpenses.count) transactions\n"
            
            if !categories.isEmpty {
                let topCategory = categories.max(by: { $0.value.count < $1.value.count })
                if let (cat, expenses) = topCategory {
                    let catTotal = expenses.reduce(0.0) { $0 + $1.amount }
                    context += "Most spent on: \(cat) ($\(String(format: "%.2f", catTotal)))\n"
                }
                
                context += "Breakdown:\n"
                for (category, expenses) in categories.sorted(by: { $0.value.count > $1.value.count }).prefix(3) {
                    let categoryTotal = expenses.reduce(0.0) { $0 + $1.amount }
                    let percentage = (categoryTotal / totalSpent) * 100
                    context += "  • \(category): $\(String(format: "%.2f", categoryTotal)) (\(Int(percentage))%)\n"
                }
            }
            context += "\n"
        }
        
        // AI-DERIVED INSIGHTS (the "learning" part)
        if !userInsights.isEmpty {
            print("   ✓ \(userInsights.keys.count) behavioral insights loaded")
            context += "BEHAVIORAL INSIGHTS:\n"
            
            if let discipline = userInsights["goalDiscipline"] as? String {
                context += "• Goal discipline: \(discipline)\n"
            }
            if let overspending = userInsights["overspendingAreas"] as? [String], !overspending.isEmpty {
                context += "• Overspending detected in: \(overspending.joined(separator: ", "))\n"
            }
            if let frequency = userInsights["spendingFrequency"] as? String {
                context += "• Spending frequency: \(frequency)\n"
            }
            if let engagement = userInsights["engagementLevel"] as? String {
                context += "• Engagement: \(engagement)\n"
            }
            if let interests = userInsights["primaryInterests"] as? [String], !interests.isEmpty {
                context += "• Interested in: \(interests.joined(separator: ", "))\n"
            }
            if let avgProgress = userInsights["averageGoalProgress"] as? Double {
                context += "• Average goal progress: \(Int(avgProgress * 100))%\n"
            }
            context += "\n"
        } else {
            print("   ✗ No behavioral insights yet")
        }
        
        print("📋 [AI] Context built: \(context.count) characters")
        if context.count < 100 {
            print("⚠️ [AI] WARNING: Context is very short - may result in generic responses!")
            print("   Context: \(context)")
        }
        
        return context.isEmpty ? "New user - building profile..." : context
    }
    
    // 🎭 ADAPTIVE TONE SYSTEM - Detect user emotional state
    private func detectUserTone(_ message: String) -> String {
        let text = message.lowercased()
        
        // Frustrated/Stressed
        if text.contains("frustrated") || text.contains("stressed") || text.contains("overwhelming") ||
           text.contains("can't") || text.contains("too hard") || text.contains("giving up") {
            return "frustrated"
        }
        
        // Confused/Lost
        if text.contains("confused") || text.contains("don't understand") || text.contains("lost") ||
           text.contains("what do i") || text.contains("help") {
            return "confused"
        }
        
        // Excited/Motivated
        if text.contains("excited") || text.contains("motivated") || text.contains("ready") ||
           text.contains("let's do") || text.contains("!") {
            return "excited"
        }
        
        // Worried/Anxious
        if text.contains("worried") || text.contains("anxious") || text.contains("scared") ||
           text.contains("nervous") || text.contains("afraid") {
            return "worried"
        }
        
        // Celebrating Progress
        if text.contains("reached") || text.contains("achieved") || text.contains("did it") ||
           text.contains("finally") {
            return "celebrating"
        }
        
        return "neutral"
    }
    
    private func getAdaptiveToneGuidance(for tone: String) -> String {
        switch tone {
        case "frustrated":
            return "User is FRUSTRATED. Use a calmer, reassuring tone. Break things into tiny steps. Remind them progress takes time. Be extra patient and supportive."
        case "confused":
            return "User is CONFUSED. Use simple language. Explain concepts clearly with examples. Avoid jargon. Be patient and encouraging."
        case "excited":
            return "User is EXCITED! Match their energy! Be enthusiastic and motivating. Celebrate their momentum. Give them actionable next steps to channel that energy."
        case "worried":
            return "User is WORRIED. Be extra reassuring. Acknowledge their concerns. Show empathy. Remind them of their progress and strengths. Offer concrete solutions."
        case "celebrating":
            return "User is CELEBRATING! Be genuinely happy for them! Acknowledge their hard work. Celebrate the win. Then gently suggest the next goal to maintain momentum."
        default:
            return "User tone is neutral. Be warm, friendly, and helpful. Maintain your encouraging personality."
        }
    }
    
    // Build insights from conversation history (SESSION + LONG-TERM MEMORY)
    private func buildConversationInsights() -> String {
        guard messages.count > 2 else {
            return "First conversation with this user."
        }
        
        // SESSION MEMORY: Recent conversation (last 6 messages)
        let recentMessages = messages.suffix(6)
        var insights = "📝 SESSION MEMORY (current conversation):\n"
        if recentMessages.count > 2 {
            insights += "Recent discussion: "
            let recentTopics = recentMessages.filter { $0.isUser }.map { $0.text }.suffix(3).joined(separator: " → ")
            insights += recentTopics
            insights += "\n\n"
        }
        
        // LONG-TERM MEMORY: All past conversations
        let userMessages = messages.filter { $0.isUser }.map { $0.text.lowercased() }
        insights += "📚 LONG-TERM MEMORY (all past topics):\n"
        var topics: [String] = []
        
        if userMessages.contains(where: { $0.contains("debt") || $0.contains("loan") || $0.contains("credit card") }) {
            topics.append("debt management")
        }
        if userMessages.contains(where: { $0.contains("invest") || $0.contains("stock") || $0.contains("401k") }) {
            topics.append("investing")
        }
        if userMessages.contains(where: { $0.contains("budget") }) {
            topics.append("budgeting")
        }
        if userMessages.contains(where: { $0.contains("save") || $0.contains("saving") }) {
            topics.append("saving strategies")
        }
        if userMessages.contains(where: { $0.contains("emergency") }) {
            topics.append("emergency fund")
        }
        if userMessages.contains(where: { $0.contains("retire") }) {
            topics.append("retirement planning")
        }
        
        insights += topics.isEmpty ? "New user, first topics" : topics.joined(separator: ", ")
        insights += "\n→ Build on ALL previous conversations. Reference what you've discussed before."
        
        return insights
    }
    
    func clearHistory() async {
        messages.removeAll()
        
        // Delete chat history from Firebase
        if let uid = userUID {
            do {
                let snapshot = try await db.collection("users").document(uid)
                    .collection("aiChatHistory")
                    .getDocuments()
                
                for doc in snapshot.documents {
                    try await doc.reference.delete()
                }
            } catch {
                print("Error clearing chat history: \(error)")
            }
        }
    }
}

enum AIError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case apiError(statusCode: Int)
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid request format"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let code):
            return "API error (status code: \(code))"
        case .parsingError:
            return "Failed to parse response"
        }
    }
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let text: String
    let isUser: Bool
    let timestamp: Date
    
    init(id: String = UUID().uuidString, text: String, isUser: Bool, timestamp: Date) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
}
