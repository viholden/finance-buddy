//
//  FileUploadManager.swift
//  finance buddy
//

import Foundation
import FirebaseStorage
import FirebaseFirestore
import UniformTypeIdentifiers

@MainActor
final class FileUploadManager: NSObject, ObservableObject {
    @Published var uploadedFiles: [FileUpload] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    // MARK: - Upload File
    
    /// Upload a file from URL to Firebase Storage and save metadata to Firestore.
    func uploadFile(from url: URL, userId: String) async throws -> FileUpload {
        let fileData = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        let fileSize = fileData.count
        let fileType = mimeType(for: url)
        
        let fileId = UUID().uuidString
        let storagePath = "users/\(userId)/uploads/\(fileId)"
        
        // Upload to Firebase Storage
        print("📤 Uploading \(fileName) to Firebase Storage...")
        let storageRef = storage.reference().child(storagePath)
        
        _ = try await storageRef.putDataAsync(fileData, metadata: nil)
        
        // Create FileUpload object
        let fileUpload = FileUpload(
            id: fileId,
            userId: userId,
            fileName: fileName,
            fileType: fileType,
            fileSize: fileSize,
            uploadedAt: Date(),
            storagePath: storagePath
        )
        
        // Save metadata to Firestore
        print("💾 Saving file metadata to Firestore...")
        try db.collection("users").document(userId)
            .collection("uploads")
            .document(fileId)
            .setData(from: fileUpload)
        
        print("✅ File uploaded successfully: \(fileName)")
        
        // Refresh the list
        try await fetchUploadedFiles(for: userId)
        
        return fileUpload
    }
    
    // MARK: - Fetch Files
    
    /// Fetch all uploaded files for a user.
    func fetchUploadedFiles(for userId: String) async throws {
        print("🔍 Fetching uploaded files for user: \(userId)")
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("uploads")
                .order(by: "uploadedAt", descending: true)
                .getDocuments()
            
            let files = snapshot.documents.compactMap { doc -> FileUpload? in
                try? doc.data(as: FileUpload.self)
            }
            
            print("✅ Fetched \(files.count) files")
            self.uploadedFiles = files
        } catch {
            print("❌ Error fetching files: \(error)")
            self.errorMessage = "Failed to load uploaded files"
            throw error
        }
    }
    
    // MARK: - Download File Content
    
    /// Download file content from Firebase Storage as Data.
    func downloadFile(storagePath: String) async throws -> Data {
        print("⬇️ Downloading file from: \(storagePath)")
        let storageRef = storage.reference().child(storagePath)
        let maxSize: Int64 = 50 * 1024 * 1024  // 50 MB limit
        
        let data = try await storageRef.data(maxSize: maxSize)
        print("✅ File downloaded successfully")
        return data
    }
    
    /// Download file content as a String (for text-based files).
    func downloadFileAsString(storagePath: String) async throws -> String {
        let data = try await downloadFile(storagePath: storagePath)
        guard let stringContent = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "FileUploadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot decode file as UTF-8"])
        }
        return stringContent
    }
    
    // MARK: - Delete File
    
    /// Delete a file from Firebase Storage and remove metadata from Firestore.
    func deleteFile(_ file: FileUpload, userId: String) async throws {
        print("🗑️ Deleting file: \(file.fileName)")
        
        // Delete from Storage
        let storageRef = storage.reference().child(file.storagePath)
        try await storageRef.delete()
        
        // Delete metadata from Firestore
        try await db.collection("users").document(userId)
            .collection("uploads")
            .document(file.id)
            .delete()
        
        print("✅ File deleted successfully")
        
        // Refresh the list
        try await fetchUploadedFiles(for: userId)
    }
    
    // MARK: - Helpers
    
    /// Determine MIME type from file extension.
    private func mimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        
        let mimeTypes: [String: String] = [
            "pdf": "application/pdf",
            "txt": "text/plain",
            "csv": "text/csv",
            "json": "application/json",
            "xml": "application/xml",
            "png": "image/png",
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "gif": "image/gif",
            "doc": "application/msword",
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "xls": "application/vnd.ms-excel",
            "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        ]
        
        return mimeTypes[pathExtension] ?? "application/octet-stream"
    }
}
