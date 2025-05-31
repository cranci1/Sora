//
//  SettingsViewDownloads.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import SwiftUI
import Drops

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
                    .tint(.accentColor.opacity(0.7))
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

fileprivate struct SettingsPickerRow<T: Hashable>: View {
    let icon: String
    let title: String
    let options: [T]
    let optionToString: (T) -> String
    @Binding var selection: T
    var showDivider: Bool = true
    
    init(icon: String, title: String, options: [T], optionToString: @escaping (T) -> String, selection: Binding<T>, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self.options = options
        self.optionToString = optionToString
        self._selection = selection
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
                
                Menu {
                    ForEach(options, id: \.self) { option in
                        Button(action: { selection = option }) {
                            Text(optionToString(option))
                        }
                    }
                } label: {
                    Text(optionToString(selection))
                        .foregroundStyle(.gray)
                }
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

struct SettingsViewDownloads: View {
    @EnvironmentObject private var jsController: JSController
    @AppStorage(DownloadQualityPreference.userDefaultsKey)
    private var downloadQuality = DownloadQualityPreference.defaultPreference.rawValue
    @AppStorage("allowCellularDownloads") private var allowCellularDownloads: Bool = true
    @AppStorage("maxConcurrentDownloads") private var maxConcurrentDownloads: Int = 3
    @State private var showClearConfirmation = false
    @State private var totalStorageSize: Int64 = 0
    @State private var existingDownloadCount: Int = 0
    @State private var isCalculating: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsSection(
                    title: "Download Settings",
                    footer: "Max concurrent downloads controls how many episodes can download simultaneously. Higher values may use more bandwidth and device resources."
                ) {
                    SettingsPickerRow(
                        icon: "4k.tv",
                        title: "Quality",
                        options: DownloadQualityPreference.allCases.map { $0.rawValue },
                        optionToString: { $0 },
                        selection: $downloadQuality
                    )
                    
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                                .frame(width: 24, height: 24)
                                .foregroundStyle(.primary)
                            
                            Text("Max Concurrent Downloads")
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Stepper("\(maxConcurrentDownloads)", value: $maxConcurrentDownloads, in: 1...10)
                                .onChange(of: maxConcurrentDownloads) { newValue in
                                    jsController.updateMaxConcurrentDownloads(newValue)
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        Divider()
                            .padding(.horizontal, 16)
                    }
                    
                    SettingsToggleRow(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "Allow Cellular Downloads",
                        isOn: $allowCellularDownloads,
                        showDivider: false
                    )
                }
                
                SettingsSection(
                    title: "Quality Information"
                ) {
                    if let preferenceDescription = DownloadQualityPreference(rawValue: downloadQuality)?.description {
                        HStack {
                            Text(preferenceDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                
                SettingsSection(
                    title: "Storage Management"
                ) {
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "externaldrive")
                                .frame(width: 24, height: 24)
                                .foregroundStyle(.primary)
                            
                            Text("Storage Used")
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            if isCalculating {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .padding(.trailing, 5)
                            }
                            
                            Text(formatFileSize(totalStorageSize))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        Divider()
                            .padding(.horizontal, 16)
                        
                        HStack {
                            Image(systemName: "doc.text")
                                .frame(width: 24, height: 24)
                                .foregroundStyle(.primary)
                            
                            Text("Files Downloaded")
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Text("\(existingDownloadCount) of \(jsController.savedAssets.count)")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        Divider()
                            .padding(.horizontal, 16)
                        
                        Button(action: {
                            calculateTotalStorage()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(.primary)
                                
                                Text("Refresh Storage Info")
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        
                        Divider()
                            .padding(.horizontal, 16)
                        
                        Button(action: {
                            showClearConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(.red)
                                
                                Text("Clear All Downloads")
                                    .foregroundStyle(.red)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Downloads")
        .scrollViewBottomPadding()
        .alert("Delete All Downloads", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                clearAllDownloads(preservePersistentDownloads: false)
            }
            Button("Clear Library Only", role: .destructive) {
                clearAllDownloads(preservePersistentDownloads: true)
            }
        } message: {
            Text("Are you sure you want to delete all downloaded assets? You can choose to clear only the library while preserving the downloaded files for future use.")
        }
        .onAppear {
            calculateTotalStorage()
            jsController.updateMaxConcurrentDownloads(maxConcurrentDownloads)
        }
    }
    
    private func calculateTotalStorage() {
        guard !jsController.savedAssets.isEmpty else {
            totalStorageSize = 0
            existingDownloadCount = 0
            return
        }
        
        isCalculating = true
        
        DownloadedAsset.clearFileSizeCache()
        DownloadGroup.clearFileSizeCache()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let total = jsController.savedAssets.reduce(0) { $0 + $1.fileSize }
            let existing = jsController.savedAssets.filter { $0.fileExists }.count
            
            DispatchQueue.main.async {
                self.totalStorageSize = total
                self.existingDownloadCount = existing
                self.isCalculating = false
            }
        }
    }
    
    private func clearAllDownloads(preservePersistentDownloads: Bool = false) {
        let assetsToDelete = jsController.savedAssets
        for asset in assetsToDelete {
            if preservePersistentDownloads {
                jsController.removeAssetFromLibrary(asset)
            } else {
                jsController.deleteAsset(asset)
            }
        }
        
        totalStorageSize = 0
        existingDownloadCount = 0
        
        NotificationCenter.default.post(name: NSNotification.Name("downloadLibraryChanged"), object: nil)
        
        DispatchQueue.main.async {
            if preservePersistentDownloads {
                DropManager.shared.success("Library cleared successfully")
            } else {
                DropManager.shared.success("All downloads deleted successfully")
            }
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
} 
