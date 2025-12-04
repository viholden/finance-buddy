//
//  RAGEngine.swift
//  finance buddy
//
//  Created by Natasha Cordova-Diba on 10/29/25.
//

import Foundation

public final class RAGEngine {
    private let embedder: EmbeddingsProvider
    private let store: VectorStore

    public init(embedder: EmbeddingsProvider, store: VectorStore) {
        self.embedder = embedder
        self.store = store
    }

    // Ingest a long text doc (e.g., CSV summary, statement OCR) for a user
    public func ingest(userId: String, doc: Document) throws {
        let pieces = Chunker.chunk(text: doc.text)
        let embs = try embedder.embedBatch(texts: pieces)
        var toUpsert: [Chunk] = []
        for i in 0..<pieces.count {
            let c = Chunk(userId: userId,
                          docId: doc.id,
                          text: pieces[i],
                          metadata: ["source": doc.source, "idx": "\(i)"],
                          embedding: embs[i])
            toUpsert.append(c)
        }
        try store.upsertMany(chunks: toUpsert)
    }

    // Ask with RAG: returns top K contexts; you can now pass these to your LLM of choice
    public func retrieve(userId: String, query: String, topK: Int = 6) throws -> [Hit] {
        let q = try embedder.embed(text: query)
        return try store.search(userId: userId, queryEmbedding: q, topK: topK)
    }

    // Utility that drafts an answer string (you may swap this for a local or remote LLM)
    public func draftAnswer(userId: String, query: String, topK: Int = 6) throws -> String {
        let hits = try retrieve(userId: userId, query: query, topK: topK)
        let ctx = hits.map { "• \($0.chunk.text)" }.joined(separator: "\n")
        return """
        Question: \(query)

        Relevant context:
        \(ctx)

        Draft answer (fill with your LLM or template):
        Based on your data, here are the key points above. If you'd like, I can run projections on goals and suggest small category cuts to reach them sooner.
        """
    }
}
