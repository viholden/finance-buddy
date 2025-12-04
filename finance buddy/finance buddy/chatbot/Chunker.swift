//
//  Chunker.swift
//  finance buddy
//
//  Created by Natasha Cordova-Diba on 10/29/25.
//

import Foundation

struct Chunker {
    /// Very simple splitter: paragraphs first, then fall back to sentence-ish splitting
    static func chunk(text: String, maxChars: Int = 800) -> [String] {
        let paras = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var chunks: [String] = []
        for p in paras {
            if p.count <= maxChars { chunks.append(p); continue }
            // naive sentence split
            let parts = p.split(whereSeparator: { ".!?".contains($0) })
            var buf = ""
            for (i, s) in parts.enumerated() {
                let candidate = buf.isEmpty ? String(s) : buf + ". " + s
                if candidate.count <= maxChars { buf = candidate }
                else { if !buf.isEmpty { chunks.append(buf + ".") }; buf = String(s) }
                if i == parts.count - 1 && !buf.isEmpty { chunks.append(buf + ".") }
            }
        }
        if chunks.isEmpty { chunks = [String(text.prefix(maxChars))] }
        return chunks
    }
}
