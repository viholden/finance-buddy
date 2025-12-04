//
//  EmbeddingsProvider.swift
//  finance buddy
//
//  Created by Natasha Cordova-Diba on 10/29/25.
//

import Foundation

public protocol EmbeddingsProvider {
    /// Return a sentence embedding (L2-normalized preferred)
    func embed(text: String) throws -> [Float]
    /// Batch encode for speed
    func embedBatch(texts: [String]) throws -> [[Float]]
}
