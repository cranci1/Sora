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
    @State private var showAlert = false
    @State private var cacheSizeText: String = "..."
    @State private var isCalculatingSize: Bool = false
    @State private var cacheSize: Int64 = 0
    @State private var documentsSize: Int64 = 0
    
    enum ActiveAlert {
        case eraseData, removeDocs, clearCache
    }
    
    @State private var activeAlert: ActiveAlert = .eraseData
    
    var body: some View {
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                SettingsSection(
                    title: NSLocalizedString("App Storage", comment: ""),
                    footer: NSLocalizedString("The app cache helps the app load images faster.\n\nClearing the Documents folder will delete all downloaded modules.\n\nErasing the App Data will clears all your settings and data of the app.", comment: "")
                ) {
                    VStack(spacing: 0) {
                        SettingsButtonRow(
                            icon: "trash",
                            title: NSLocalizedString("Remove All Cache", comment: ""),
                            subtitle: cacheSizeText,
                            action: {
                                activeAlert = .clearCache
                                showAlert = true
                            }
                        )
                        
                        Divider().padding(.horizontal, 16)
                        
                        SettingsButtonRow(
                            icon: "doc.text",
                            title: NSLocalizedString("Remove All Documents", comment: ""),
                            subtitle: formatSize(documentsSize),
                            action: {
                                activeAlert = .removeDocs
                                showAlert = true
                            }
                        )
                        
                        Divider().padding(.horizontal, 16)
                        
                        SettingsButtonRow(
                            icon: "exclamationmark.triangle",
                            title: NSLocalizedString("Erase all App Data", comment: ""),
                            action: {
                                activeAlert = .eraseData
                                showAlert = true
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 20)
            .scrollViewBottomPadding()
            .navigationTitle(NSLocalizedString("App Data", comment: ""))
            .onAppear {
                calculateCacheSize()
                updateSizes()
            }
            .alert(isPresented: $showAlert) {
                switch activeAlert {
                case .eraseData:
                    return Alert(
                        title: Text(NSLocalizedString("Erase App Data", comment: "")),
                        message: Text(NSLocalizedString("Are you sure you want to erase all app data? This action cannot be undone.", comment: "")),
                        primaryButton: .destructive(Text(NSLocalizedString("Erase", comment: ""))) {
                            eraseAppData()
                        },
                        secondaryButton: .cancel()
                    )
                case .removeDocs:
                    return Alert(
                        title: Text(NSLocalizedString("Remove Documents", comment: "")),
                        message: Text(NSLocalizedString("Are you sure you want to remove all files in the Documents folder? This will remove all modules.", comment: "")),
                        primaryButton: .destructive(Text(NSLocalizedString("Remove", comment: ""))) {
                            removeAllFilesInDocuments()
                        },
                        secondaryButton: .cancel()
                    )
                case .clearCache:
                    return Alert(
                        title: Text(NSLocalizedString("Clear Cache", comment: "")),
                        message: Text(NSLocalizedString("Are you sure you want to clear all cached data? This will help free up storage space.", comment: "")),
                        primaryButton: .destructive(Text(NSLocalizedString("Clear", comment: ""))) {
                            clearAllCaches()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
    }
    
    func calculateCacheSize() {
        isCalculatingSize = true
        cacheSizeText = "..."
        
        DispatchQueue.global(qos: .background).async {
            if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let size = calculateDirectorySize(for: cacheURL)
                DispatchQueue.main.async {
                    self.cacheSize = size
                    self.cacheSizeText = formatSize(size)
                    self.isCalculatingSize = false
                }
            } else {
                DispatchQueue.main.async {
                    self.cacheSizeText = "N/A"
                    self.isCalculatingSize = false
                }
            }
        }
    }
    
    func updateSizes() {
        DispatchQueue.global(qos: .background).async {
            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let size = calculateDirectorySize(for: documentsURL)
                DispatchQueue.main.async {
                    self.documentsSize = size
                }
            }
        }
    }
    
    func clearAllCaches() {
        clearCache()
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
                    if fileURL.lastPathComponent == "Backups" { continue } // Skip Backups folder
                    try fileManager.removeItem(at: fileURL)
                }
                Logger.shared.log("All files in documents folder removed (except Backups)", type: "General")
                exit(0)
            } catch {
                Logger.shared.log("Error removing files in documents folder: \(error)", type: "Error")
            }
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
            Logger.shared.log("Error calculating directory size: \(error)", type: "Error")
        }
        
        return totalSize
    }
    
    func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
