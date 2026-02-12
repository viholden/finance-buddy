//
//  FinanceBuddyRAGService.swift
//  finance buddy
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import NaturalLanguage

@MainActor
final class FinanceBuddyRAGService: ObservableObject {

    static let shared = FinanceBuddyRAGService()

    private let db: Firestore
    private let storage: Storage
    private let embedding: NLEmbedding
    private var indexedUserId: String?
    private var index: [IndexedChunk] = []

    // Optional reference to the app's AuthenticationManager so the service
    // can operate on the currently authenticated user without callers
    // having to pass the UID every time.
    private weak var authManager: AuthenticationManager?

    /// Attach an `AuthenticationManager` instance to the service.
    /// Call this once (for example from App or ContentView) after the
    /// app has created the manager.
    func attach(authManager: AuthenticationManager) {
        self.authManager = authManager
    }

    /// Convenience computed property that prefers the attached
    /// `AuthenticationManager`'s `userId`, falling back to Firebase's
    /// current user if needed.
    private var currentUserId: String? {
        authManager?.userId ?? Auth.auth().currentUser?.uid
    }

    private struct IndexedChunk {
        let id: String
        let userId: String
        let source: String
        let text: String
        let vector: [Double]
    }

    // MARK: - Init

    private init() {
        // Make sure Firebase is configured in AppDelegate/@main BEFORE this is touched
        guard FirebaseApp.app() != nil else {
            fatalError("🔥 FirebaseApp.configure() must be called before using FinanceBuddyRAGService.")
        }

        self.db = Firestore.firestore()
        self.storage = Storage.storage()

        guard let emb = NLEmbedding.sentenceEmbedding(for: .english) else {
            fatalError("🔥 NLEmbedding.sentenceEmbedding(.english) is not available on this device.")
        }
        self.embedding = emb
    }

    // MARK: - Public API

    /// Rebuild semantic index for this user's data from Firestore.
    func refreshIndex(for userId: String) async throws {
        var chunks: [IndexedChunk] = []

        let userRef = db.collection("users").document(userId)

        // --- Expenses ---
        let expSnap = try await userRef.collection("expenses").getDocuments()
        for doc in expSnap.documents {
            if let e = try? doc.data(as: Expense.self) {
                let text =
                  "Expense: \(e.category) — $\(String(format: "%.2f", e.amount)) at \(e.merchant). \(e.description)"
                if let vec = embed(text) {
                    chunks.append(
                        IndexedChunk(
                            id: doc.documentID,
                            userId: userId,
                            source: "expenses",
                            text: text,
                            vector: vec
                        )
                    )
                }
            }
        }

        // --- Goals ---
        let goalSnap = try await userRef.collection("goals").getDocuments()
        for doc in goalSnap.documents {
            if let g = try? doc.data(as: Goal.self) {
                let text =
                  "Goal: \(g.name). Target: \(String(format: "%.2f", g.targetAmount)). " + "Current: \(String(format: "%.2f", g.currentAmount))."
                if let vec = embed(text) {
                    chunks.append(
                        IndexedChunk(
                            id: doc.documentID,
                            userId: userId,
                            source: "goals",
                            text: text,
                            vector: vec
                        )
                    )
                }
            }
        }

        // --- Profile ---
        let profileDoc = try await userRef.getDocument()
        if let profile = try? profileDoc.data(as: UserProfile.self) {
            let text =
              "User profile: \(profile.name). Email: \(profile.email). " +
              "Total points: \(profile.totalPoints). Currency: \(profile.currency)."
            if let vec = embed(text) {
                chunks.append(
                    IndexedChunk(
                        id: "profile_\(userId)",
                        userId: userId,
                        source: "profile",
                        text: text,
                        vector: vec
                    )
                )
            }
        }

        // --- Uploaded Files ---
        let uploadsSnap = try await userRef.collection("uploads").getDocuments()
        for doc in uploadsSnap.documents {
            if let file = try? doc.data(as: FileUpload.self) {
                // Index the file metadata
                let metadataText = "Uploaded file: \(file.fileName). Type: \(file.fileType). Size: \(file.formattedSize). Uploaded: \(file.uploadedAt.formatted())"
                if let vec = embed(metadataText) {
                    chunks.append(
                        IndexedChunk(
                            id: file.id,
                            userId: userId,
                            source: "uploads_metadata",
                            text: metadataText,
                            vector: vec
                        )
                    )
                }
                
                // For text-based files, also index the content
                if isTextBasedFile(file.fileType) {
                    do {
                        let fileContent = try await downloadFileContent(storagePath: file.storagePath)
                        // Chunk large files into smaller snippets for better embedding
                        let snippets = chunkText(fileContent, maxLength: 500)
                        for (index, snippet) in snippets.enumerated() {
                            if let vec = embed(snippet) {
                                chunks.append(
                                    IndexedChunk(
                                        id: "\(file.id)_chunk_\(index)",
                                        userId: userId,
                                        source: "uploads_content",
                                        text: "From \(file.fileName): \(snippet)",
                                        vector: vec
                                    )
                                )
                            }
                        }
                    } catch {
                        print("⚠️ [RAG] Failed to download and index content from \(file.fileName): \(error)")
                    }
                }
            }
        }

        self.index = chunks
        self.indexedUserId = userId
    }

    /// Build a RAG-style prompt string with top-K similar snippets from this user's data.
    func buildPrompt(
        userId: String,
        question: String,
        topK: Int = 6
    ) async throws -> String {
        // Make sure index is ready for this user
        if index.isEmpty || indexedUserId != userId {
            try await refreshIndex(for: userId)
        }

        guard let qVec = embed(question) else {
            return "Question: \(question)\n\n(No contextual data available yet.)"
        }

        // Rank chunks by cosine similarity
        let scored = index.map { chunk in
            (chunk, cosineSimilarity(qVec, chunk.vector))
        }

        let top = scored
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map { $0.0 }

        let context = top.map { "• \($0.text)" }.joined(separator: "\n")

        return """
        Question: \(question)

        Relevant context from this user's data:
        \(context)

        When answering, focus on the context above. Be specific, explain any assumptions,
        and clearly separate general advice from user-specific information.
        """
    }

    // MARK: - Convenience for current user

    enum FinanceBuddyRAGServiceError: Error {
        case notAuthenticated
    }

    /// Refresh the semantic index for the currently authenticated user (if available).
    func refreshIndexForCurrentUser() async throws {
        guard let uid = currentUserId else {
            throw FinanceBuddyRAGServiceError.notAuthenticated
        }
        try await refreshIndex(for: uid)
    }

    /// Build a prompt for the currently authenticated user (if available).
    func buildPromptForCurrentUser(question: String, topK: Int = 6) async throws -> String {
        guard let uid = currentUserId else {
            throw FinanceBuddyRAGServiceError.notAuthenticated
        }
        return try await buildPrompt(userId: uid, question: question, topK: topK)
    }

    // MARK: - Helpers

    private func embed(_ text: String) -> [Double]? {
        embedding.vector(for: text)
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        let n = min(a.count, b.count)
        if n == 0 { return 0 }
        var dot = 0.0
        var magA = 0.0
        var magB = 0.0
        for i in 0..<n {
            let x = a[i]
            let y = b[i]
            dot += x * y
            magA += x * x
            magB += y * y
        }
        let denom = (magA.squareRoot() * magB.squareRoot())
        return denom == 0 ? 0 : dot / denom
    }

    // MARK: - File Handling

    /// Check if a file type is text-based and suitable for content indexing.
    private func isTextBasedFile(_ fileType: String) -> Bool {
        let textTypes = [
            "text/plain",
            "text/csv",
            "application/json",
            "application/xml",
            "text/html"
        ]
        return textTypes.contains(fileType.lowercased())
    }

    /// Download file content from Firebase Storage.
    private func downloadFileContent(storagePath: String) async throws -> String {
        let storageRef = storage.reference().child(storagePath)
        let maxSize: Int64 = 10 * 1024 * 1024  // 10 MB limit
        let data = try await storageRef.data(maxSize: maxSize)

        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "FinanceBuddyRAGService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot decode file content as UTF-8"])
        }
        return content
    }

    /// Split text into smaller chunks for better embedding quality.
    private func chunkText(_ text: String, maxLength: Int = 500) -> [String] {
        let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var chunks: [String] = []
        var currentChunk = ""

        for word in words {
            if (currentChunk + " " + word).count > maxLength {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                currentChunk = word
            } else {
                if currentChunk.isEmpty {
                    currentChunk = word
                } else {
                    currentChunk += " " + word
                }
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }
}

