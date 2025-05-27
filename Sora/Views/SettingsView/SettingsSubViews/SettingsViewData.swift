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
    @Binding
    var isOn: Bool
    var showDivider: Bool = true

    init(icon: String, title: String, isOn: Binding < Bool > , showDivider: Bool = true) {
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
                    .tint(.accentColor)
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

    @State private var isMetadataCachingEnabled: Bool = true
    @State private var isImageCachingEnabled: Bool = true
    @State private var isMemoryOnlyMode: Bool = false

    enum ActiveAlert {
        case eraseData, removeDocs, removeMovPkg
    }

    @State private var showAlert = false
    @State private var activeAlert: ActiveAlert = .eraseData

    var body: some View {
        ScrollView {
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
                        Text("Current Metadata Cache Size")
                        Spacer()
                        if isCalculatingSize {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(.trailing, 5)
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

                        Button(action: clearAllCaches) {
                            HStack {
                                Image(systemName: "trash")
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(.red)

                                Text("Clear All Caches")
                                    .foregroundStyle(.red)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }

                    Button(action: clearAllCaches) {
                        Text("Clear All Metadata Caches")
                            .foregroundColor(.red)
                    }
                }

                Section(header: Text("App storage"), footer: Text("The caches used by Sora are stored images that help load content faster\n\nThe App Data should never be erased if you dont know what that will cause.\n\nClearing the documents folder will remove all the modules and downloads")) {
                    HStack {
                        Button(action: clearCache) {
                            HStack {
                                Image(systemName: "trash")
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(.red)

                                Text("Clear Cache")
                                    .foregroundStyle(.red)

                                Spacer()

                                Text(formatSize(cacheSize))
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        Divider()
                            .padding(.horizontal, 16)

                        Button(action: {
                            activeAlert = .removeDocs
                            showAlert = true
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(.red)

                                Text("Remove All Files in Documents")
                                    .foregroundStyle(.red)

                                Spacer()

                                Text(formatSize(documentsSize))
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        Divider()
                            .padding(.horizontal, 16)

                        Button(action: {
                            showRemoveMovPkgAlert = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(.red)

                                Text("Remove Downloads")
                                    .foregroundStyle(.red)

                                Spacer()

                                Text(formatSize(movPkgSize))
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        Divider()
                            .padding(.horizontal, 16)

                        Button(action: {
                            activeAlert = .eraseData
                            showAlert = true
                        }) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(.red)

                                Text("Erase all App Data")
                                    .foregroundStyle(.red)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .scrollViewBottomPadding()
            .navigationTitle("App Data")
            .navigationViewStyle(StackNavigationViewStyle())
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
        let cacheURL = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask).first

        do {
            if let cacheURL = cacheURL {
                let filePaths =
                    try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil, options: [])
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
        if let documentsURL = fileManager.urls(
            for: .documentDirectory, in: .userDomainMask).first {
            do {
                let fileURLs =
                    try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
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
        if let documentsURL = fileManager.urls(
            for: .documentDirectory, in: .userDomainMask).first {
            do {
                let fileURLs =
                    try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
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
            let contents =
                try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
            for url in contents {
                let resourceValues =
                    try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
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
        if let cacheURL = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask).first {
            cacheSize = calculateDirectorySize(for: cacheURL)
        }

        if let documentsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first {
            documentsSize = calculateDirectorySize(for: documentsURL)
            movPkgSize = calculateMovPkgSize(in: documentsURL)
        }
    }

    private func calculateMovPkgSize(in url: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        do {
            let contents =
                try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
            for url in contents where url.pathExtension == "movpkg" {
                let resourceValues =
                    try url.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        } catch {
            Logger.shared.log("Error calculating MovPkg size: \(error)", type: "Error")
        }

        return totalSize
    }
}