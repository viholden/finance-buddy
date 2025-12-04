//
//  VectorStore.swift
//  finance buddy
//
//  Created by Natasha Cordova-Diba on 10/29/25.
//

import Foundation

public protocol VectorStore {
    func upsert(chunk: Chunk) throws
    func upsertMany(chunks: [Chunk]) throws
    func search(userId: String, queryEmbedding: [Float], topK: Int) throws -> [Hit]
}

@inline(__always)
func cosine(_ a: [Float], _ b: [Float]) -> Float {
    var dot: Float = 0, na: Float = 0, nb: Float = 0
    let n = min(a.count, b.count)
    for i in 0..<n { dot += a[i]*b[i]; na += a[i]*a[i]; nb += b[i]*b[i] }
    guard na > 0, nb > 0 else { return 0 }
    return dot / (sqrt(na) * sqrt(nb))
}
