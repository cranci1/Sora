import SwiftUI

struct OrphanedDownloadsView: View {
    @State private var orphanedFiles: [URL] = []
    @State private var selectedFiles: Set<URL> = []
    @State private var showDeleteConfirmation = false
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(LocalizedStringKey("Orphaned Downloads"))
                    .font(.title2)
                    .bold()
                Spacer()
                if !selectedFiles.isEmpty {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .padding()
            if isLoading {
                ProgressView()
                    .padding()
                Spacer()
            } else if orphanedFiles.isEmpty {
                Text(LocalizedStringKey("No orphaned files found."))
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
            } else {
                VStack(spacing: 0) {
                    Button(role: .destructive) {
                        selectedFiles = Set(orphanedFiles)
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text(LocalizedStringKey("Delete All Orphaned Files"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(orphanedFiles, id: \.self) { file in
                                ZStack(alignment: .topTrailing) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(file.lastPathComponent)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Text(fileSizeString(for: file))
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(UIColor.systemBackground))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(
                                                        selectedFiles.contains(file) ? Color.accentColor : Color.gray.opacity(0.2),
                                                        lineWidth: selectedFiles.contains(file) ? 2 : 1
                                                    )
                                            )
                                    )
                                    .onTapGesture {
                                        if selectedFiles.contains(file) {
                                            selectedFiles.remove(file)
                                        } else {
                                            selectedFiles.insert(file)
                                        }
                                    }
                                    if selectedFiles.contains(file) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 28, height: 28)
                                            Image(systemName: "checkmark")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 16, height: 16)
                                                .foregroundColor(.accentColor)
                                        }
                                        .offset(x: -8, y: 8)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
            }
        }
        .onAppear(perform: loadOrphanedFiles)
        .alert(LocalizedStringKey("Delete Selected Files?"), isPresented: $showDeleteConfirmation) {
            Button(LocalizedStringKey("Cancel"), role: .cancel) {}
            Button(LocalizedStringKey("Delete"), role: .destructive) {
                deleteSelectedFiles()
            }
        } message: {
            Text(LocalizedStringKey("Are you sure you want to delete the selected orphaned files? This action cannot be undone."))
        }
    }
    
    private func loadOrphanedFiles() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let files = DownloadPersistence.orphanedFiles()
            DispatchQueue.main.async {
                self.orphanedFiles = files
                self.selectedFiles = []
                self.isLoading = false
            }
        }
    }
    
    private func fileSizeString(for url: URL) -> String {
        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
        let size = resourceValues?.fileSize ?? 0
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    private func deleteSelectedFiles() {
        let jsonFileName = "downloads.json"
        var deletedCount = 0
        for file in selectedFiles {
            if file.lastPathComponent == jsonFileName { continue }
            if (try? FileManager.default.removeItem(at: file)) != nil {
                deletedCount += 1
            }
        }
        loadOrphanedFiles()
        if deletedCount > 0 {
            DropManager.shared.success(String(format: NSLocalizedString("%d file(s) deleted successfully", comment: "Success message for deleted orphaned files"), deletedCount))
        }
    }
} 