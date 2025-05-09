//
//  SettingsViewData.swift
//  Sora
//
//  Created by Francesco on 05/02/25.
//

import SwiftUI

struct SettingsViewData: View {
    @State private var showEraseAppDataAlert = false
    @State private var showRemoveDocumentsAlert = false
    @State private var showSizeAlert = false
    @State private var cacheSize: Int64 = 0
    @State private var documentsSize: Int64 = 0
    
    var body: some View {
        Form {
            Section(header: Text("App storage"), footer: Text("The caches used by Sora are stored images that help load content faster\n\nThe App Data should never be erased if you dont know what that will cause.\n\nClearing the documents folder will remove all the modules and downloads")) {
                HStack {
                    Button(action: clearCache) {
                        Text("Clear Cache")
                    }
                    Spacer()
                    Text("\(formatSize(cacheSize))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Button(action: {
                        showRemoveDocumentsAlert = true
                    }) {
                        Text("Remove All Files in Documents")
                    }
                    Spacer()
                    Text("\(formatSize(documentsSize))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    showEraseAppDataAlert = true
                }) {
                    Text("Erase all App Data")
                }
            }
        }
        .navigationTitle("App Data")
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            updateSizes()
        }
    }
    
    func eraseAppData() {
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
            Logger.shared.log("Cleared app data!", type: "General")
            exit(0)
        }
    }
    
    func clearCache() {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        
        do {
            if let cacheURL = cacheURL {
                let filePaths = try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil, options: [])
                for filePath in filePaths {
                    try FileManager.default.removeItem(at: filePath)
                }
                Logger.shared.log("Cache cleared successfully!", type: "General")
                updateSizes()
            }
        } catch {
            Logger.shared.log("Failed to clear cache.", type: "Error")
        }
    }
    
    func removeAllFilesInDocuments() {
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                for fileURL in fileURLs {
                    try fileManager.removeItem(at: fileURL)
                }
                Logger.shared.log("All files in documents folder removed", type: "General")
                exit(0)
            } catch {
                Logger.shared.log("Error removing files in documents folder: \(error)", type: "Error")
            }
        }
    }
    
    private func calculateDirectorySize(for url: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if resourceValues.isDirectory == true {
                    totalSize += calculateDirectorySize(for: url)
                } else {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            }
        } catch {
            Logger.shared.log("Error calculating directory size: \(error)", type: "Error")
        }
        
        return totalSize
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func updateSizes() {
        if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            cacheSize = calculateDirectorySize(for: cacheURL)
        }
        
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            documentsSize = calculateDirectorySize(for: documentsURL)
        }
    }
}
