//
//  SettingsViewDownloads.swift
//  Sora
//
//  Created by Francesco on 29/04/25.
//

import SwiftUI

struct SettingsViewDownloads: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    @AppStorage("downloadQuality") private var downloadQuality: String = "Best"
    @AppStorage("allowCellularDownloads") private var allowCellularDownloads: Bool = true
    @AppStorage("autoStartDownloads") private var autoStartDownloads: Bool = true
    @AppStorage("maxConcurrentDownloads") private var maxConcurrentDownloads: Int = 3
    @AppStorage("deleteWatchedDownloads") private var deleteWatchedDownloads: Bool = false
    @AppStorage("downloadLocation") private var downloadLocation: String = "Documents"
    @AppStorage("storageLimitGB") private var storageLimitGB: Int = 10
    @AppStorage("autoCleanupEnabled") private var autoCleanupEnabled: Bool = true
    @AppStorage("cleanupThreshold") private var cleanupThreshold: Double = 0.8
    
    @State private var showClearConfirmation = false
    @State private var showStorageLimitAlert = false
    @State private var newStorageLimit: Int = 10
    
    private let qualityOptions = ["Best", "High", "Medium", "Low"]
    private let locationOptions = ["Documents", "Cache"]
    private let maxConcurrentOptions = [1, 2, 3, 5, 10]
    private let storageLimitOptions = [5, 10, 20, 50, 100]
    private let cleanupThresholdOptions = [0.7, 0.8, 0.9]
    
    var body: some View {
        Form {
            Section(header: Text("Download Settings")) {
                Picker("Quality", selection: $downloadQuality) {
                    ForEach(qualityOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                
                Picker("Storage Location", selection: $downloadLocation) {
                    ForEach(locationOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                
                Picker("Max Concurrent Downloads", selection: $maxConcurrentDownloads) {
                    ForEach(maxConcurrentOptions, id: \.self) { option in
                        Text("\(option)").tag(option)
                    }
                }
                
                Toggle("Allow Cellular Downloads", isOn: $allowCellularDownloads)
                    .tint(.accentColor)
                
                Toggle("Auto-Start Downloads", isOn: $autoStartDownloads)
                    .tint(.accentColor)
                
                Toggle("Delete Watched Downloads", isOn: $deleteWatchedDownloads)
                    .tint(.accentColor)
            }
            
            Section(header: Text("Storage Management")) {
                HStack {
                    Text("Storage Used")
                    Spacer()
                    Text(formatFileSize(downloadManager.totalStorageUsed))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Storage Limit")
                    Spacer()
                    TextField("GB", value: $storageLimitGB, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .onChange(of: storageLimitGB) { newValue in
                            if newValue <= 0 {
                                storageLimitGB = 1
                            }
                            downloadManager.setStorageLimit(Int64(storageLimitGB) * 1024 * 1024 * 1024)
                        }
                    Text("GB")
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: downloadManager.getStorageUsagePercentage()) {
                    Text("\(Int(downloadManager.getStorageUsagePercentage() * 100))% Used")
                }
                
                Toggle("Auto Cleanup", isOn: $autoCleanupEnabled)
                    .tint(.accentColor)
                
                if autoCleanupEnabled {
                    Picker("Cleanup Threshold", selection: $cleanupThreshold) {
                        Text("70%").tag(0.7)
                        Text("80%").tag(0.8)
                        Text("90%").tag(0.9)
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
                        clearAllDownloads()
                    }
                } message: {
                    Text("Are you sure you want to delete all downloaded episodes? This action cannot be undone.")
                }
            }
        }
        .navigationTitle("Downloads")
        .onAppear {
            downloadManager.setStorageLimit(Int64(storageLimitGB) * 1024 * 1024 * 1024)
        }
        .onChange(of: storageLimitGB) { newValue in
            downloadManager.setStorageLimit(Int64(newValue) * 1024 * 1024 * 1024)
        }
        .alert("Set Storage Limit", isPresented: $showStorageLimitAlert) {
            Picker("Storage Limit", selection: $newStorageLimit) {
                ForEach(storageLimitOptions, id: \.self) { option in
                    Text("\(option) GB").tag(option)
                }
            }
            Button("Cancel", role: .cancel) { }
            Button("Set") {
                storageLimitGB = newStorageLimit
            }
        } message: {
            Text("Select the maximum amount of storage to use for downloads")
        }
    }
    
    private func clearAllDownloads() {
        let episodesToDelete = downloadManager.savedEpisodes
        for episode in episodesToDelete {
            downloadManager.deleteEpisode(episode)
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
} 