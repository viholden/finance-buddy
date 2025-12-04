//
//  SQLiteVectorStore.swift
//  finance buddy
//
//  Created by Natasha Cordova-Diba on 10/29/25.
//

import Foundation
import SQLite3

public final class SQLiteVectorStore: VectorStore {
    private var db: OpaquePointer?

    public init(path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK { throw NSError(domain:"SQLite", code:1) }
        try exec("""
        CREATE TABLE IF NOT EXISTS chunks(
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          doc_id TEXT NOT NULL,
          text TEXT NOT NULL,
          metadata TEXT,
          embedding BLOB NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_chunks_user ON chunks(user_id);
        """)
    }

    deinit { if db != nil { sqlite3_close(db) } }

    public func upsert(chunk: Chunk) throws { try upsertMany(chunks: [chunk]) }

    public func upsertMany(chunks: [Chunk]) throws {
        guard let db = db, !chunks.isEmpty else { return }
        try exec("BEGIN")
        let sql = "REPLACE INTO chunks(id,user_id,doc_id,text,metadata,embedding) VALUES(?,?,?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw dbError }
        defer { sqlite3_finalize(stmt) }
        for c in chunks {
            let meta = try JSONSerialization.data(withJSONObject: c.metadata ?? [:], options: [])
            let emb = try serialize(c.embedding ?? [])
            // Use nil instead of SQLITE_TRANSIENT - tells SQLite to copy the data
            sqlite3_bind_text(stmt, 1, c.id, -1, nil)
            sqlite3_bind_text(stmt, 2, c.userId, -1, nil)
            sqlite3_bind_text(stmt, 3, c.docId, -1, nil)
            sqlite3_bind_text(stmt, 4, c.text, -1, nil)
            meta.withUnsafeBytes { p in _ = sqlite3_bind_blob(stmt, 5, p.baseAddress, Int32(meta.count), nil) }
            emb.withUnsafeBytes { p in _ = sqlite3_bind_blob(stmt, 6, p.baseAddress, Int32(emb.count), nil) }
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw dbError }
            sqlite3_reset(stmt)
        }
        try exec("COMMIT")
    }

    public func search(userId: String, queryEmbedding: [Float], topK: Int) throws -> [Hit] {
        guard let db = db else { return [] }
        var stmt: OpaquePointer?
        let sql = "SELECT id, doc_id, text, metadata, embedding FROM chunks WHERE user_id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw dbError }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, userId, -1, nil)

        var hits: [Hit] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let docId = String(cString: sqlite3_column_text(stmt, 1))
            let text = String(cString: sqlite3_column_text(stmt, 2))
            let metaData = dataAt(stmt, idx: 3)
            let meta = (try? JSONSerialization.jsonObject(with: metaData)) as? [String:String]
            let embData = dataAt(stmt, idx: 4)
            let emb = deserialize(embData)

            let score = cosine(queryEmbedding, emb)
            let chunk = Chunk(id: id, userId: userId, docId: docId, text: text, metadata: meta, embedding: emb)
            hits.append(Hit(chunk: chunk, score: score))
        }
        return Array(hits.sorted { $0.score > $1.score }.prefix(topK))
    }

    // MARK: - helpers
    private func exec(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw dbError }
    }
    private var dbError: NSError {
        NSError(domain: "SQLite", code: 2, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(db))])
    }
    private func dataAt(_ stmt: OpaquePointer?, idx: Int32) -> Data {
        let len = Int(sqlite3_column_bytes(stmt, idx))
        let bytes = sqlite3_column_blob(stmt, idx)
        return Data(bytes: bytes!, count: len)
    }
    private func serialize(_ v: [Float]) throws -> Data {
        var vv = v
        return vv.withUnsafeBytes { Data($0) }
    }
    private func deserialize(_ d: Data) -> [Float] {
        Array(UnsafeBufferPointer<Float>(start: d.withUnsafeBytes { $0.bindMemory(to: Float.self).baseAddress! },
                                         count: d.count / MemoryLayout<Float>.stride))
    }
}
