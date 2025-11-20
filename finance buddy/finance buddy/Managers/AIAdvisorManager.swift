import Foundation
import Combine

class AIAdvisorManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Using LM Studio local server - 100% FREE, runs on your Mac!
    // Download LM Studio: https://lmstudio.ai
    // Model: Mistral-7B-Instruct-v0.3
    private let apiURL = "http://127.0.0.1:1234/v1/chat/completions"
    private let modelName = "mistralai/mistral-7b-instruct-v0.3"
    private var cancellables = Set<AnyCancellable>()
    
    // Store user context
    private var userProfile: UserProfile?
    private var recentExpenses: [Expense] = []
    private var activeGoals: [Goal] = []
    private var questionnaireResponses: QuestionnaireResponse?
    
    func updateUserContext(
        profile: UserProfile?,
        expenses: [Expense],
        goals: [Goal],
        questionnaire: QuestionnaireResponse?
    ) {
        self.userProfile = profile
        self.recentExpenses = expenses
        self.activeGoals = goals
        self.questionnaireResponses = questionnaire
    }
    
    func sendMessage(_ text: String) async {
        let userMessage = ChatMessage(text: text, isUser: true, timestamp: Date())
        
        await MainActor.run {
            messages.append(userMessage)
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await generateResponse(for: text)
            let aiMessage = ChatMessage(text: response, isUser: false, timestamp: Date())
            
            await MainActor.run {
                messages.append(aiMessage)
                isLoading = false
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
        // LM Studio is too slow - using fast rule-based advisor instead
        return generateSmartResponse(for: userInput)
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
    
    private func generateResponseFromLMStudio(for userInput: String) async throws -> String {
        let context = buildUserContext()
        // Shortened prompt for faster responses
        let systemPrompt = """
        You are a financial advisor. Give concise, helpful advice.
        User context: \(context)
        """
        
        // Build messages array - LM Studio only supports user/assistant roles
        var apiMessages: [[String: String]] = []
        
        // Add only last 3 messages for faster processing
        let conversationHistory = messages.suffix(3).map { message in
            ["role": message.isUser ? "user" : "assistant", "content": message.text]
        }
        apiMessages.append(contentsOf: conversationHistory)
        
        // Add current user message (only include context on first message)
        let isFirstMessage = messages.isEmpty
        let userMessageContent = isFirstMessage ? "\(systemPrompt)\n\n\(userInput)" : userInput
        apiMessages.append(["role": "user", "content": userMessageContent])
        
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": apiMessages,
            "temperature": 0.5,
            "max_tokens": 200,
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
        request.timeoutInterval = 60 // 60 second timeout for local LLM
        // No API key needed - LM Studio runs locally!
        
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorText = String(data: data, encoding: .utf8) {
                print("API Error (\(httpResponse.statusCode)): \(errorText)")
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
        var context = ""
        
        // User profile info
        if let profile = userProfile {
            context += "User Name: \(profile.name)\n"
            context += "Total Points Earned: \(profile.totalPoints)\n"
            context += "Currency: \(profile.currency)\n\n"
        }
        
        // Questionnaire responses
        if let responses = questionnaireResponses {
            context += "Financial Profile:\n"
            if let goal = responses.financialGoal {
                context += "- Primary Goal: \(goal)\n"
            }
            if let income = responses.incomeRange {
                context += "- Income Range: \(income)\n"
            }
            if let risk = responses.riskTolerance {
                context += "- Risk Tolerance: \(risk)\n"
            }
            if let experience = responses.savingsExperience {
                context += "- Savings Experience: \(experience)\n"
            }
            if let expenses = responses.expenses, !expenses.isEmpty {
                context += "- Major Expenses: \(expenses.joined(separator: ", "))\n"
            }
            if let concerns = responses.primaryConcerns, !concerns.isEmpty {
                context += "- Primary Concerns: \(concerns.joined(separator: ", "))\n"
            }
            if let comments = responses.additionalComments, !comments.isEmpty {
                context += "- Additional Notes: \(comments)\n"
            }
            context += "\n"
        }
        
        // Active goals
        if !activeGoals.isEmpty {
            context += "Active Savings Goals:\n"
            for goal in activeGoals.prefix(5) {
                let progress = goal.targetAmount > 0 ? (goal.currentAmount / goal.targetAmount) * 100 : 0
                context += "- \(goal.name): $\(Int(goal.currentAmount))/$\(Int(goal.targetAmount)) (\(Int(progress))% complete)\n"
            }
            context += "\n"
        }
        
        // Recent spending
        if !recentExpenses.isEmpty {
            let totalSpent = recentExpenses.reduce(0.0) { $0 + $1.amount }
            let categories = Dictionary(grouping: recentExpenses, by: { $0.category })
            
            context += "Recent Spending:\n"
            context += "- Total: $\(String(format: "%.2f", totalSpent))\n"
            context += "- Number of Transactions: \(recentExpenses.count)\n"
            
            if !categories.isEmpty {
                context += "- By Category:\n"
                for (category, expenses) in categories.sorted(by: { $0.value.count > $1.value.count }).prefix(5) {
                    let categoryTotal = expenses.reduce(0.0) { $0 + $1.amount }
                    context += "  • \(category): $\(String(format: "%.2f", categoryTotal)) (\(expenses.count) transactions)\n"
                }
            }
            context += "\n"
        }
        
        return context.isEmpty ? "No financial data available yet." : context
    }
    
    func clearHistory() {
        messages.removeAll()
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
