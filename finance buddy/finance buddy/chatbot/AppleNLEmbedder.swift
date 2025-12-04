//
//  AppleNLEmbedder.swift
//  finance buddy
//
//  Uses Apple's Natural Language framework for sentence embeddings
//  No external model file required - uses built-in Apple embeddings
//

import Foundation
import NaturalLanguage

public final class AppleNLEmbedder: EmbeddingsProvider {
    private let embedding: NLEmbedding
    
    public init() throws {
        // Use Apple's built-in word embedding model
        // We'll aggregate word embeddings to create sentence embeddings
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else {
            throw NSError(
                domain: "AppleNLEmbedder",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load Apple's word embedding model"]
            )
        }
        self.embedding = embedding
    }
    
    public func embed(text: String) throws -> [Float] {
        let out = try embedBatch(texts: [text])
        return out[0]
    }
    
    public func embedBatch(texts: [String]) throws -> [[Float]] {
        var results: [[Float]] = []
        results.reserveCapacity(texts.count)
        
        for text in texts {
            let sentenceEmbedding = try createSentenceEmbedding(from: text)
            results.append(sentenceEmbedding)
        }
        
        return results
    }
    
    /// Creates a sentence embedding by averaging word embeddings
    private func createSentenceEmbedding(from text: String) throws -> [Float] {
        // Tokenize the text into words
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.english)
        
        var wordEmbeddings: [[Double]] = []
        var totalWeight: Double = 0
        
        // Get embeddings for each word
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let word = String(text[tokenRange]).lowercased()
            
            // Get word embedding
            if let vector = embedding.vector(for: word) {
                wordEmbeddings.append(vector)
                totalWeight += 1.0
            }
            return true
        }
        
        // If no words found, return zero vector
        guard !wordEmbeddings.isEmpty else {
            // Return a zero vector with the dimension of the embedding
            // Apple's word embeddings are typically 300 dimensions
            return Array(repeating: 0.0, count: 300).map { Float($0) }
        }
        
        // Average the word embeddings to create sentence embedding
        let dimension = wordEmbeddings[0].count
        var sentenceVector = Array(repeating: 0.0, count: dimension)
        
        for wordVec in wordEmbeddings {
            for i in 0..<dimension {
                sentenceVector[i] += wordVec[i]
            }
        }
        
        // Normalize by count
        if totalWeight > 0 {
            for i in 0..<dimension {
                sentenceVector[i] /= totalWeight
            }
        }
        
        // Convert to Float array and L2 normalize
        let floatVector = sentenceVector.map { Float($0) }
        return AppleNLEmbedder.l2normalize(floatVector)
    }
    
    private static func l2normalize(_ v: [Float]) -> [Float] {
        let s = sqrt(v.reduce(0) { $0 + $1*$1 })
        guard s > 0 else { return v }
        return v.map { $0 / s }
    }
}

