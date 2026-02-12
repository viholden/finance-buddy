//
//  FileUpload.swift
//  finance buddy
//

import Foundation

/// Represents a file uploaded by the user to be used in AI Advisor context.
struct FileUpload: Identifiable, Codable {
    let id: String
    let userId: String
    let fileName: String
    let fileType: String  // e.g., "application/pdf", "text/plain"
    let fileSize: Int     // in bytes
    let uploadedAt: Date
    let storagePath: String  // Full path in Firebase Storage, e.g., "users/{uid}/uploads/{fileId}"
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case fileName
        case fileType
        case fileSize
        case uploadedAt
        case storagePath
    }
    
    /// Human-readable file size (e.g., "2.5 MB")
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
    
    /// File icon based on type
    var fileIcon: String {
        switch fileType.lowercased() {
        case "application/pdf":
            return "doc.fill"
        case "text/plain":
            return "doc.text.fill"
        case "text/csv":
            return "tablecells.fill"
        case "application/json":
            return "doc.text.fill"
        case "image/png", "image/jpeg":
            return "photo.fill"
        default:
            return "doc.fill"
        }
    }
}
