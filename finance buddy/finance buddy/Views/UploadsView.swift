//
//  UploadsView.swift
//  finance buddy
//

import SwiftUI

struct UploadsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var uploadManager = FileUploadManager()
    
    @State private var showingDocumentPicker = false
    @State private var selectedFile: FileUpload?
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Uploaded Files")
                                    .font(.headline)
                                Text("\(uploadManager.uploadedFiles.count) file\(uploadManager.uploadedFiles.count != 1 ? "s" : "")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        
                        Button(action: { showingDocumentPicker = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add File")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.2, green: 0.7, blue: 0.5))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
                    
                    // File List
                    if uploadManager.isLoading {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading files...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxHeight: .infinity)
                        .frame(maxWidth: .infinity)
                    } else if uploadManager.uploadedFiles.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            
                            Text("No files uploaded yet")
                                .font(.headline)
                            Text("Upload financial documents to provide context for AI advice")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxHeight: .infinity)
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(uploadManager.uploadedFiles) { file in
                                    FileUploadCell(file: file)
                                        .onTapGesture {
                                            selectedFile = file
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                selectedFile = file
                                                showingDeleteConfirmation = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding()
                        }
                    }
                    
                    // Error message
                    if let error = uploadManager.errorMessage {
                        VStack {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                Spacer()
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Uploads")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.pdf, .plainText, .data, .image],
            onCompletion: { result in
                handleFileSelection(result)
            }
        )
        .alert("Delete File?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let file = selectedFile {
                    Task {
                        do {
                            if let uid = authManager.user?.uid {
                                try await uploadManager.deleteFile(file, userId: uid)
                            }
                        } catch {
                            print("❌ Error deleting file: \(error)")
                        }
                    }
                }
            }
        } message: {
            Text("This will permanently delete '\(selectedFile?.fileName ?? "this file")'.")
        }
        .task {
            if let uid = authManager.user?.uid {
                try? await uploadManager.fetchUploadedFiles(for: uid)
            }
        }
    }
    
    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            
            Task {
                do {
                    if let uid = authManager.user?.uid {
                        let file = try await uploadManager.uploadFile(from: url, userId: uid)
                        print("✅ Successfully uploaded: \(file.fileName)")
                    }
                } catch {
                    print("❌ Error uploading file: \(error)")
                }
            }
            
        case .failure(let error):
            print("❌ Error selecting file: \(error)")
        }
    }
}

struct FileUploadCell: View {
    let file: FileUpload
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: file.fileIcon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                    .frame(width: 40, height: 40)
                    .background(Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.fileName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(file.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider()
                            .frame(height: 12)
                        
                        Text(file.uploadedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
    }
}

#Preview {
    UploadsView()
        .environmentObject(AuthenticationManager())
}
