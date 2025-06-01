//
//  SettingsViewData.swift
//  Sora
//
//  Created by Francesco on 05/02/25.
//

import SwiftUI

fileprivate struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content
    
    init(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.footnote)
                .foregroundStyle(.gray)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                content
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
            
            if let footer = footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
    }
}

fileprivate struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    var showDivider: Bool = true
    
    init(icon: String, title: String, isOn: Binding<Bool>, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self._isOn = isOn
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.primary)
                
                Text(title)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.accentColor.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
}

fileprivate struct SettingsButtonRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let action: () -> Void
    
    init(icon: String, title: String, subtitle: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.red)
                
                Text(title)
                    .foregroundStyle(.red)
                
                Spacer()
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

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
    @State private var isMetadataCachingEnabled: Bool = false
    @State private var isImageCachingEnabled: Bool = true
    @State private var isMemoryOnlyMode: Bool = false
    @State private var showAlert = false
    
    enum ActiveAlert {
        case eraseData, removeDocs, removeMovPkg
    }
    
    @State private var activeAlert: ActiveAlert = .eraseData
    
    var body: some View {
        return ScrollView {
            VStack(spacing: 24) {
                SettingsSection(
                    title: "Cache Settings",
                    footer: "Caching helps reduce network usage and load content faster. You can disable it to save storage space."
                ) {
                    SettingsToggleRow(
                        icon: "doc.text",
                        title: "Enable Metadata Caching",
                        isOn: $isMetadataCachingEnabled
                    )
                    .onChange(of: isMetadataCachingEnabled) { newValue in
                        MetadataCacheManager.shared.isCachingEnabled = newValue
                        if !newValue {
                            calculateCacheSize()
                        }
                    }
                    
                    SettingsToggleRow(
                        icon: "photo",
                        title: "Enable Image Caching",
                        isOn: $isImageCachingEnabled
                    )
                    .onChange(of: isImageCachingEnabled) { newValue in
                        KingfisherCacheManager.shared.isCachingEnabled = newValue
                        if !newValue {
                            calculateCacheSize()
                        }
                    }
                    
                    if isMetadataCachingEnabled {
                        SettingsToggleRow(
                            icon: "memorychip",
                            title: "Memory-Only Mode",
                            isOn: $isMemoryOnlyMode
                        )
                        .onChange(of: isMemoryOnlyMode) { newValue in
                            MetadataCacheManager.shared.isMemoryOnlyMode = newValue
                            if newValue {
                                MetadataCacheManager.shared.clearAllCache()
                                calculateCacheSize()
                            }
                        }
                    }
                    
                    HStack {
                        Image(systemName: "folder.badge.gearshape")
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.primary)
                        
                        Text("Current Cache Size")
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        if isCalculatingSize {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(.trailing, 5)
                        }
                        
                        Text(cacheSizeText)
                            .foregroundStyle(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    Divider().padding(.horizontal, 16)
                    
                    Button(action: clearAllCaches) {
                        Text("Clear All Caches")
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                SettingsSection(
                    title: "App Storage",
                    footer: "The App Data should never be erased if you don't know what that will cause.\nClearing the documents folder will remove all the modules and downloads\n "
                ) {
                    VStack(spacing: 0) {
                        SettingsButtonRow(
                            icon: "doc.text",
                            title: "Remove All Files in Documents",
                            subtitle: formatSize(documentsSize),
                            action: {
                                activeAlert = .removeDocs
                                showAlert = true
                            }
                        )
                        Divider().padding(.horizontal, 16)
                        
                        SettingsButtonRow(
                            icon: "arrow.down.circle",
                            title: "Remove Downloads",
                            subtitle: formatSize(movPkgSize),
                            action: {
                                showRemoveMovPkgAlert = true
                            }
                        )
                        Divider().padding(.horizontal, 16)
                        
                        SettingsButtonRow(
                            icon: "exclamationmark.triangle",
                            title: "Erase all App Data",
                            action: {
                                activeAlert = .eraseData
                                showAlert = true
                            }
                        )
                    }
                }
            }
            .scrollViewBottomPadding()
            .navigationTitle("App Data")
            .onAppear {
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
                        primaryButton: .destructive(Text("Erase")) {
                            eraseAppData()
                        },
                        secondaryButton: .cancel()
                    )
                case .removeDocs:
                    return Alert(
                        title: Text("Remove Documents"),
                        message: Text("Are you sure you want to remove all files in the Documents folder? This will remove all modules."),
                        primaryButton: .destructive(Text("Remove")) {
                            removeAllFilesInDocuments()
                        },
                        secondaryButton: .cancel()
                    )
                case .removeMovPkg:
                    return Alert(
                        title: Text("Remove Downloads"),
                        message: Text("Are you sure you want to remove all Downloads?"),
                        primaryButton: .destructive(Text("Remove")) {
                            removeMovPkgFiles()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        
        
        func calculateCacheSize() {
            isCalculatingSize = true
            cacheSizeText = "Calculating..."
            DispatchQueue.global(qos: .background).async {
                var totalSize: Int64 = 0
                let metadataSize = MetadataCacheManager.shared.getCacheSize()
                totalSize += metadataSize
                
                KingfisherCacheManager.shared.calculateCacheSize { imageSize in
                    totalSize += Int64(imageSize)
                    DispatchQueue.main.async {
                        self.cacheSizeText = KingfisherCacheManager.formatCacheSize(UInt(totalSize))
                        self.isCalculatingSize = false
                    }
                }
            }
        }
        
        func clearAllCaches() {
            MetadataCacheManager.shared.clearAllCache()
            KingfisherCacheManager.shared.clearCache {
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
                    Logger.shared.log("Error removing files in documents folder: $error)", type: "Error")
                }
            }
        }
        
        func removeMovPkgFiles() {
            let fileManager = FileManager.default
            if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                do {
                    let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                    for fileURL in fileURLs where fileURL.pathExtension == "movpkg" {
                        try fileManager.removeItem(at: fileURL)
                    }
                    Logger.shared.log("All Downloads files removed", type: "General")
                    updateSizes()
                } catch {
                    Logger.shared.log("Error removing Downloads files: $error)", type: "Error")
                }
            }
        }
        
        func calculateDirectorySize(for url: URL) -> Int64 {
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
                Logger.shared.log("Error calculating directory size: $error)", type: "Error")
            }
            return totalSize
        }
        
        func formatSize(_ bytes: Int64) -> String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: bytes) ?? "\(bytes) bytes"
        }
        
        func updateSizes() {
            if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                cacheSize = calculateDirectorySize(for: cacheURL)
            }
            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                documentsSize = calculateDirectorySize(for: documentsURL)
                movPkgSize = calculateMovPkgSize(in: documentsURL)
            }
        }
        
        func calculateMovPkgSize(in url: URL) -> Int64 {
            let fileManager = FileManager.default
            var totalSize: Int64 = 0
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
                for url in contents where url.pathExtension == "movpkg" {
                    let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                Logger.shared.log("Error calculating MovPkg size: $error)", type: "Error")
            }
            return totalSize
        }
    }
}
