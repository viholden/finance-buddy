//
//  Models.swift
//  finance buddy
//
//  Created by Natasha Cordova-Diba on 10/29/25.
//

import Foundation

public struct Document: Identifiable, Codable {
    public let id: String
    public let userId: String
    public let text: String
    public let source: String
    public let createdAt: Date

    public init(id: String = UUID().uuidString,
                userId: String, text: String, source: String, createdAt: Date = .init()) {
        self.id = id; self.userId = userId; self.text = text; self.source = source; self.createdAt = createdAt
    }
}

public struct Chunk: Identifiable, Codable {
    public let id: String
    public let userId: String
    public let docId: String
    public let text: String
    public let metadata: [String: String]?
    public let embedding: [Float]?

    public init(id: String = UUID().uuidString,
                userId: String, docId: String, text: String,
                metadata: [String: String]? = nil, embedding: [Float]? = nil) {
        self.id = id; self.userId = userId; self.docId = docId; self.text = text
        self.metadata = metadata; self.embedding = embedding
    }
}

public struct Hit: Codable {
    public let chunk: Chunk
    public let score: Float
}
