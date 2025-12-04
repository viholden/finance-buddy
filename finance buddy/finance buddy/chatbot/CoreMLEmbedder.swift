//
//  CoreMLEmbedder.swift
//  finance buddy
//
//  Created by Natasha Cordova-Diba on 10/29/25.
//

import Foundation
import CoreML
import FirebaseFirestore
import FirebaseAuth

public final class CoreMLEmbedder: EmbeddingsProvider {
    private let model: MLModel
    private let inputName: String
    private let outputName: String

    public init(modelURL: URL,
                inputName: String = "text",
                outputName: String = "embedding") throws {
        self.model = try MLModel(contentsOf: modelURL)
        self.inputName = inputName
        self.outputName = outputName
    }

    public func embed(text: String) throws -> [Float] {
        let out = try predict(texts: [text])
        return out[0]
    }

    public func embedBatch(texts: [String]) throws -> [[Float]] {
        return try predict(texts: texts)
    }

    private func predict(texts: [String]) throws -> [[Float]] {
        // For most sentence models you'll loop per text.
        // If your model supports batched inputs, adapt this to a single prediction call.
        var results: [[Float]] = []
        results.reserveCapacity(texts.count)
        for t in texts {
            let dict = try MLDictionaryFeatureProvider(dictionary: [inputName: t])
            let pred = try model.prediction(from: dict)
            guard let vec = pred.featureValue(for: outputName)?.multiArrayValue else {
                throw NSError(domain: "CoreMLEmbedder", code: 2, userInfo: [NSLocalizedDescriptionKey: "No embedding output"])
            }
            let floats = try convertMultiArrayToFloats(vec)
            results.append(CoreMLEmbedder.l2normalize(floats))
        }
        return results
    }
    
    /// Convert MLMultiArray to [Float] array
    private func convertMultiArrayToFloats(_ multiArray: MLMultiArray) throws -> [Float] {
        let count = multiArray.count
        var floats: [Float] = []
        floats.reserveCapacity(count)
        
        // Handle different data types that MLMultiArray might contain
        switch multiArray.dataType {
        case .float32:
            let pointer = multiArray.dataPointer.bindMemory(to: Float32.self, capacity: count)
            for i in 0..<count {
                floats.append(Float(pointer[i]))
            }
        case .double:
            let pointer = multiArray.dataPointer.bindMemory(to: Double.self, capacity: count)
            for i in 0..<count {
                floats.append(Float(pointer[i]))
            }
        case .int32:
            let pointer = multiArray.dataPointer.bindMemory(to: Int32.self, capacity: count)
            for i in 0..<count {
                floats.append(Float(pointer[i]))
            }
        default:
            throw NSError(
                domain: "CoreMLEmbedder",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported MLMultiArray data type: \(multiArray.dataType.rawValue)"]
            )
        }
        
        return floats
    }

    private static func l2normalize(_ v: [Float]) -> [Float] {
        let s = sqrt(v.reduce(0) { $0 + $1*$1 })
        guard s > 0 else { return v }
        return v.map { $0 / s }
    }
}
