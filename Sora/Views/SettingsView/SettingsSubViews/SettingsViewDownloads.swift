//
//  SettingsViewDownloads.swift
//  Sora
//
//  Created by Francesco on 29/04/25.
//

import SwiftUI
import Drops

// No need to import DownloadQualityPreference as it's in the same module

struct SettingsViewDownloads: View {
    @ObservedObject private var jsController = JSController()
    @AppStorage(DownloadQualityPreference.userDefaultsKey) 
    private var downloadQuality = DownloadQualityPreference.defaultPreference.rawValue
    @AppStorage("allowCellularDownloads") private var allowCellularDownloads: Bool = true
    @State private var showClearConfirmation = false
    
    // Calculate total storage used
    private var totalStorageUsed: Int64 {
        return jsController.savedAssets.compactMap { $0.fileSize }.reduce(0, +)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Download Settings")) {
                Picker("Quality", selection: $downloadQuality) {
                    ForEach(DownloadQualityPreference.allCases, id: \.rawValue) { option in
                        Text(option.rawValue)
                            .tag(option.rawValue)
                    }
                }
                .onChange(of: downloadQuality) { newValue in
                    print("Download quality preference changed to: \(newValue)")
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
                    Text(formatFileSize(totalStorageUsed))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Files Downloaded")
                    Spacer()
                    Text("\(jsController.savedAssets.count)")
                        .foregroundColor(.secondary)
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
                        clearAllDownloads()
                    }
                } message: {
                    Text("Are you sure you want to delete all downloaded assets? This action cannot be undone.")
                }
            }
        }
        .navigationTitle("Downloads")
    }
    
    private func clearAllDownloads() {
        let assetsToDelete = jsController.savedAssets
        for asset in assetsToDelete {
            jsController.deleteAsset(asset)
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
} 