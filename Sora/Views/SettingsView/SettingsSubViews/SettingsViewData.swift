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
    @State private var cacheSizeText: String = "Calculating..."
    @State private var isCalculatingSize: Bool = false
    @State private var cacheSize: Int64 = 0
    @State private var documentsSize: Int64 = 0
    @State private var movPkgSize: Int64 = 0
    @State private var showRemoveMovPkgAlert = false
    
    // State bindings for cache settings
    @State private var isMetadataCachingEnabled: Bool = true
    @State private var isImageCachingEnabled: Bool = true
    @State private var isMemoryOnlyMode: Bool = false
    
    enum ActiveAlert { case eraseData, removeDocs, removeMovPkg }

    @State private var showAlert = false
    @State private var activeAlert: ActiveAlert = .eraseData
    
    var body: some View {
        Form {
            // New section for cache settings
            Section(header: Text("Cache Settings"), footer: Text("Caching helps reduce network usage and load content faster. You can disable it to save storage space.")) {
                Toggle("Enable Metadata Caching", isOn: $isMetadataCachingEnabled)
                    .onChange(of: isMetadataCachingEnabled) { newValue in
                        MetadataCacheManager.shared.isCachingEnabled = newValue
                        if !newValue {
                            calculateCacheSize()
                        }
                    }
                
                Toggle("Enable Image Caching", isOn: $isImageCachingEnabled)
                    .onChange(of: isImageCachingEnabled) { newValue in
                        KingfisherCacheManager.shared.isCachingEnabled = newValue
                        if !newValue {
                            calculateCacheSize()
                        }
                    }
                
                if isMetadataCachingEnabled {
                    Toggle("Memory-Only Mode", isOn: $isMemoryOnlyMode)
                        .onChange(of: isMemoryOnlyMode) { newValue in
                            MetadataCacheManager.shared.isMemoryOnlyMode = newValue
                            if newValue {
                                // Clear disk cache when switching to memory-only
                                MetadataCacheManager.shared.clearAllCache()
                                calculateCacheSize()
                            }
                        }
                }
                
                HStack {
                    Text("Current Cache Size")
                    Spacer()
                    if isCalculatingSize {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.trailing, 5)
                    }
                    Text(cacheSizeText)
                        .foregroundColor(.secondary)
                }
                
                Button(action: clearAllCaches) {
                    Text("Clear All Caches")
                        .foregroundColor(.red)
                }
            }
            
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
                        activeAlert = .removeDocs
                        showAlert = true
                    }) {
                        Text("Remove All Files in Documents")
                    }
                    Spacer()
                    Text("\(formatSize(documentsSize))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Button(action: {
                        showRemoveMovPkgAlert = true
                    }) {
                        Text("Remove Downloads")
                    }
                    Spacer()
                    Text("\(formatSize(movPkgSize))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    activeAlert = .eraseData
                    showAlert = true
                }) {
                    Text("Erase all App Data")
                }
            }
        }
        .navigationTitle("App Data")
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Initialize state with current values
            isMetadataCachingEnabled = MetadataCacheManager.shared.isCachingEnabled
            isImageCachingEnabled = KingfisherCacheManager.shared.isCachingEnabled
            isMemoryOnlyMode = MetadataCacheManager.shared.isMemoryOnlyMode
            calculateCacheSize()
            updateSizes()
        }
        .alert(isPresented: $showAlert) {
          switch activeAlert {
          case .eraseData:
            return Alert(
              title: Text("Erase App Data"),
              message: Text("Are you sure you want to erase all app data? This action cannot be undone."),
              primaryButton: .destructive(Text("Erase")) { eraseAppData() },
              secondaryButton: .cancel()
            )
          case .removeDocs:
            return Alert(
              title: Text("Remove Documents"),
              message: Text("Are you sure you want to remove all files in the Documents folder? This will remove all modules."),
              primaryButton: .destructive(Text("Remove")) { removeAllFilesInDocuments() },
              secondaryButton: .cancel()
            )
          case .removeMovPkg:
            return Alert(
              title: Text("Remove Downloads"),
              message: Text("Are you sure you want to remove all Downloads?"),
              primaryButton: .destructive(Text("Remove")) { removeMovPkgFiles() },
              secondaryButton: .cancel()
            )
          }
        }
      }
    
    // Calculate and update the combined cache size
    func calculateCacheSize() {
        isCalculatingSize = true
        cacheSizeText = "Calculating..."
        
        // Group all cache size calculations
        DispatchQueue.global(qos: .background).async {
            var totalSize: Int64 = 0
            
            // Get metadata cache size
            let metadataSize = MetadataCacheManager.shared.getCacheSize()
            totalSize += metadataSize
            
            // Get image cache size asynchronously
            KingfisherCacheManager.shared.calculateCacheSize { imageSize in
                totalSize += Int64(imageSize)
                
                // Update the UI on the main thread
                DispatchQueue.main.async {
                    self.cacheSizeText = KingfisherCacheManager.formatCacheSize(UInt(totalSize))
                    self.isCalculatingSize = false
                }
            }
        }
    }
    
    // Clear all caches (both metadata and images)
    func clearAllCaches() {
        // Clear metadata cache
        MetadataCacheManager.shared.clearAllCache()
        
        // Clear image cache
        KingfisherCacheManager.shared.clearCache {
            // Update cache size after clearing
            calculateCacheSize()
        }
        
        Logger.shared.log("All caches cleared", type: "General")
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
                calculateCacheSize()
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
    
    func removeMovPkgFiles() {
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                for fileURL in fileURLs {
                    if fileURL.pathExtension == "movpkg" {
                        try fileManager.removeItem(at: fileURL)
                    }
                }
                Logger.shared.log("All Downloads files removed", type: "General")
                updateSizes()
            } catch {
                Logger.shared.log("Error removing Downloads files: \(error)", type: "Error")
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
            movPkgSize = calculateMovPkgSize(in: documentsURL)
        }
    }
    
    private func calculateMovPkgSize(in url: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
            for url in contents where url.pathExtension == "movpkg" {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        } catch {
            Logger.shared.log("Error calculating MovPkg size: \(error)", type: "Error")
        }
        
        return totalSize
    }
}
