//
//  SettingsViewDownloads.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import SwiftUI
import Drops

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
        Form {
            Section(header: Text("Download Settings"), footer: Text("Max concurrent downloads controls how many episodes can download simultaneously. Higher values may use more bandwidth and device resources.")) {
                Picker("Quality", selection: $downloadQuality) {
                    ForEach(DownloadQualityPreference.allCases, id: \.rawValue) { option in
                        Text(option.rawValue)
                            .tag(option.rawValue)
                    }
                }
                .onChange(of: downloadQuality) { newValue in
                    print("Download quality preference changed to: \(newValue)")
                }
                
                HStack {
                    Text("Max Concurrent Downloads")
                    Spacer()
                    Stepper("\(maxConcurrentDownloads)", value: $maxConcurrentDownloads, in: 1...10)
                        .onChange(of: maxConcurrentDownloads) { newValue in
                            jsController.updateMaxConcurrentDownloads(newValue)
                        }
                }
                
                Toggle("Allow Cellular Downloads", isOn: $allowCellularDownloads)
                    .tint(.accentColor)
            }
            
            Section(header: Text("Quality Information")) {
                if let preferenceDescription = DownloadQualityPreference(rawValue: downloadQuality)?.description {
                    Text(preferenceDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Storage Management")) {
                HStack {
                    Text("Storage Used")
                    Spacer()
                    
                    if isCalculating {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.trailing, 5)
                    }
                    
                    Text(formatFileSize(totalStorageSize))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Files Downloaded")
                    Spacer()
                    Text("\(existingDownloadCount) of \(jsController.savedAssets.count)")
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    calculateTotalStorage()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Storage Info")
                    }
                }
                
                Button(action: {
                    showClearConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("Clear All Downloads")
                            .foregroundColor(.red)
                    }
                }
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
            }
        }
        .navigationTitle("Downloads")
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
