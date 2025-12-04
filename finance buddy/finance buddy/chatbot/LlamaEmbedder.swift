//
//  LlamaEmbedder.swift
//  finance buddy
//
//  Created by Natasha Cordova-Diba on 10/29/25.
//

import Foundation

public final class LlamaEmbedder: EmbeddingsProvider {
    private let handle: OpaquePointer

    public init(modelPath: String, contextLength: Int = 8192) throws {
        // handle = llama_init_embedding_model(modelPath, Int32(contextLength))
        // guard handle != nil else { throw ... }
        self.handle = OpaquePointer(bitPattern: 0x01)! // placeholder for compilation
    }

    public func embed(text: String) throws -> [Float] {
        // let vec = llama_embed(handle, text)
        // return l2normalize(vec)
        return [] // placeholder
    }

    public func embedBatch(texts: [String]) throws -> [[Float]] {
        // return texts.map { try! embed(text: $0) }
        return []
    }
}
