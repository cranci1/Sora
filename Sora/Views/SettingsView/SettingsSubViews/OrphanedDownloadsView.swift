import SwiftUI
import Drops

struct OrphanedDownloadsView: View {
    @State private var orphanedFiles: [URL] = []
    @State private var selectedFiles: Set<URL> = []
    @State private var showDeleteConfirmation = false
    @State private var isLoading = false
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if isLoading {
                        loadingView
                    } else if orphanedFiles.isEmpty {
                        emptyStateView
                    } else {
                        orphanedFilesListView
                        
                        if !selectedFiles.isEmpty {
                            deleteSelectedButton
                        }
                    }
                }
                .padding(.vertical, 20)
                .scrollViewBottomPadding()
            }
            .navigationTitle("Orphaned Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !orphanedFiles.isEmpty && !isLoading {
                        Button(action: {
                            loadOrphanedFiles()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.primary)
                        }
                    } else {
                        // Empty spacer to maintain layout when refresh button is hidden
                        Color.clear.frame(width: 20, height: 20)
                    }
                }
            }
        }
        .onAppear(perform: loadOrphanedFiles)
        .alert(NSLocalizedString("Delete Selected Files?", comment: ""), isPresented: $showDeleteConfirmation) {
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("Delete", comment: ""), role: .destructive) {
                deleteSelectedFiles()
            }
        } message: {
            Text(NSLocalizedString("Are you sure you want to delete the selected orphaned files? This action cannot be undone.", comment: ""))
        }
    }
    
    // MARK: - Extracted Views
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .padding()
            Text(NSLocalizedString("Loading orphaned files...", comment: ""))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(minHeight: 300)
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 50))
                .foregroundColor(.green)
                .padding()
            Text(NSLocalizedString("No orphaned files found", comment: ""))
                .font(.headline)
                .foregroundColor(.primary)
            Text(NSLocalizedString("Your downloads are well-organized", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(minHeight: 300)
    }
    
    private var orphanedFilesListView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(NSLocalizedString("ORPHANED FILES", comment: ""))
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            orphanedFilesContainer
        }
    }
    
    private var orphanedFilesContainer: some View {
        VStack(spacing: 0) {
            deleteAllButton
            
            Divider()
                .padding(.horizontal, 16)
            
            ForEach(orphanedFiles, id: \.self) { file in
                fileRow(for: file)
                
                if file != orphanedFiles.last {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.accentColor.opacity(0.3), location: 0),
                            .init(color: Color.accentColor.opacity(0), location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .padding(.horizontal, 20)
    }
    
    private var deleteAllButton: some View {
        Button(action: {
            selectedFiles = Set(orphanedFiles)
            showDeleteConfirmation = true
        }) {
            HStack {
                Image(systemName: "trash")
                    .frame(width: 24, height: 24)
                    .foregroundColor(.red)
                
                Text(NSLocalizedString("Delete All Orphaned Files", comment: ""))
                    .foregroundColor(.red)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    private func fileRow(for file: URL) -> some View {
        Button(action: {
            if selectedFiles.contains(file) {
                selectedFiles.remove(file)
            } else {
                selectedFiles.insert(file)
            }
        }) {
            HStack {
                Image(systemName: selectedFiles.contains(file) ? "checkmark.circle.fill" : "circle")
                    .frame(width: 24, height: 24)
                    .foregroundColor(selectedFiles.contains(file) ? .accentColor : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.lastPathComponent)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(fileSizeString(for: file))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    private var deleteSelectedButton: some View {
        Button(action: {
            showDeleteConfirmation = true
        }) {
            Text(String(format: NSLocalizedString("Delete Selected (%d)", comment: "Button to delete selected orphaned files with count"), selectedFiles.count))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Helper Methods
    
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