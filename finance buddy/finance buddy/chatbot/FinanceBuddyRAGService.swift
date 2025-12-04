//
//  FinanceBuddyRAGService.swift
//  finance buddy
//

import Foundation
import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class FinanceBuddyRAGService: ObservableObject {
    init(engine: RAGEngine) {
        self.engine = engine
        // If Firebase is already configured, set up Firestore immediately.
        if FirebaseApp.app() != nil {
            self.db = Firestore.firestore()
        } else {
            // Wait for Firebase to finish configuring, then set up Firestore.
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(setupFirestoreIfNeeded),
                                                   name: Notification.Name("FirebaseAppReady"),
                                                   object: nil)
        }
    }

    let engine: RAGEngine
    private var db: Firestore?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func setupFirestoreIfNeeded() {
        if FirebaseApp.app() != nil {
            self.db = Firestore.firestore()
            NotificationCenter.default.removeObserver(self)
        }
    }

    private func requireDB() throws -> Firestore { if let db = self.db { return db }; throw NSError(domain: "FinanceBuddyRAGService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Firebase is not configured."]) }

    func ingestStatement(userId: String, text: String, source: String) {
        let doc = Document(userId: userId, text: text, source: source)
        try? engine.ingest(userId: userId, doc: doc)
    }

    /// Fetch user's collections from Firestore and ingest them into the RAG store.
    /// This pulls `expenses`, `goals`, and the top-level user profile and ingests
    /// a short human-readable summary for each document.
    @MainActor
    func ingestFromFirestore(userId: String) async -> String {
        var reportLines: [String] = []

        do {
            // Fetch expenses
            let db = try requireDB()
            let expSnap = try await db.collection("users").document(userId).collection("expenses").getDocuments()
            let expenses = expSnap.documents.compactMap { doc -> Expense? in
                try? doc.data(as: Expense.self)
            }

            for e in expenses {
                let text = "Expense: \(e.category) — $\(String(format: "%.2f", e.amount)) at \(e.merchant). Description: \(e.description)"
                let doc = Document(id: e.id, userId: userId, text: text, source: "expenses")
                do {
                    try engine.ingest(userId: userId, doc: doc)
                    reportLines.append("Ingested expense: \(e.id)")
                } catch {
                    reportLines.append("Failed to ingest expense \(e.id): \(error)")
                }
            }

            // Fetch goals
            let goalsSnap = try await db.collection("users").document(userId).collection("goals").getDocuments()
            let goals = goalsSnap.documents.compactMap { doc -> Goal? in
                try? doc.data(as: Goal.self)
            }

            for g in goals {
                let text = "Goal: \(g.name). Target: $\(String(format: "%.2f", g.targetAmount)). Current: $\(String(format: "%.2f", g.currentAmount))."
                let doc = Document(id: g.id, userId: userId, text: text, source: "goals")
                do {
                    try engine.ingest(userId: userId, doc: doc)
                    reportLines.append("Ingested goal: \(g.id)")
                } catch {
                    reportLines.append("Failed to ingest goal \(g.id): \(error)")
                }
            }

            // Fetch user profile
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if let profile = try? userDoc.data(as: UserProfile.self) {
                let text = "User: \(profile.name) — email: \(profile.email). Total points: \(profile.totalPoints). Currency: \(profile.currency)"
                let doc = Document(id: "profile_\(userId)", userId: userId, text: text, source: "profile")
                do {
                    try engine.ingest(userId: userId, doc: doc)
                    reportLines.append("Ingested user profile")
                } catch {
                    reportLines.append("Failed to ingest user profile: \(error)")
                }
            } else {
                reportLines.append("No user profile document found or failed to decode.")
            }

            if reportLines.isEmpty { return "No documents found to ingest for user \(userId)." }
            return reportLines.joined(separator: "\n")
        } catch {
            return "Error fetching from Firestore: \(error)"
        }
    }

    func ask(userId: String, query: String) async -> String {
        (try? engine.draftAnswer(userId: userId, query: query))
        ?? "Sorry, I couldn’t retrieve context yet."
    }
}

