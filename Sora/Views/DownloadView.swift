//
//  DownloadView.swift
//  Sulfur
//
//  Created by Francesco on 29/04/25.
//

import SwiftUI
import AVKit
import Kingfisher
import UIKit

struct DownloadView: View {
    @State private var searchText = ""
    
    // Use the shared JSController instance
    @StateObject private var jsController = JSController.shared
    @State private var selectedTab = 0
    @State private var showDeleteAlert = false
    @State private var assetToDelete: DownloadedAsset?
    @State private var sortOption: SortOption = .newest
    
    enum SortOption {
        case newest, oldest, title
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Tab selector for Active/Downloaded
                Picker("Download Status", selection: $selectedTab) {
                    Text("Active").tag(0)
                    Text("Downloaded").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if selectedTab == 0 {
                    // ACTIVE DOWNLOADS
                    if jsController.activeDownloads.isEmpty {
                        emptyActiveDownloadsView
                    } else {
                        activeDownloadsList
                    }
                } else {
                    // DOWNLOADED CONTENT
                    if jsController.savedAssets.isEmpty {
                        emptyDownloadsView
                    } else {
                        downloadedContentList
                    }
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                if selectedTab == 1 && !jsController.savedAssets.isEmpty {
                    Menu {
                        Button("Sort by Newest") { sortOption = .newest }
                        Button("Sort by Oldest") { sortOption = .oldest }
                        Button("Sort by Title") { sortOption = .title }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search downloads")
            .alert("Delete Download", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let asset = assetToDelete {
                        jsController.deleteAsset(asset)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this download?")
            }
        }
    }
    
    // MARK: - Active Downloads List
    private var activeDownloadsList: some View {
        List {
            ForEach(jsController.activeDownloads) { download in
                ActiveDownloadRow(download: download)
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Downloaded Content List
    private var downloadedContentList: some View {
        List {
            ForEach(filterAndSortAssets()) { asset in
                DownloadedAssetRow(asset: asset)
                    .contextMenu {
                        Button(role: .destructive, action: { confirmDelete(asset) }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .onTapGesture {
                        playAsset(asset)
                    }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    // MARK: - Empty States
    private var emptyActiveDownloadsView: some View {
        VStack {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding()
            
            Text("No Active Downloads")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("Download episodes from the episode list")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyDownloadsView: some View {
        VStack {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding()
            
            Text("No Downloads")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("Your downloaded assets will appear here")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    private func confirmDelete(_ asset: DownloadedAsset) {
        assetToDelete = asset
        showDeleteAlert = true
    }
    
    private func playAsset(_ asset: DownloadedAsset) {
        // Create a player for the downloaded file
        if UserDefaults.standard.string(forKey: "externalPlayer") == "Default" {
            let player = AVPlayer(url: asset.localURL)
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(playerViewController, animated: true) {
                    player.play()
                }
            }
        } else {
            // Using custom player - simplified for now
            let player = AVPlayer(url: asset.localURL)
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(playerViewController, animated: true) {
                    player.play()
                }
            }
        }
    }
    
    // MARK: - Data Organization
    private func filterAndSortAssets() -> [DownloadedAsset] {
        let filteredAssets = searchText.isEmpty
            ? jsController.savedAssets
            : jsController.savedAssets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        
        switch sortOption {
        case .newest:
            return filteredAssets.sorted { $0.downloadDate > $1.downloadDate }
        case .oldest:
            return filteredAssets.sorted { $0.downloadDate < $1.downloadDate }
        case .title:
            return filteredAssets.sorted { $0.name < $1.name }
        }
    }
}

// MARK: - ActiveDownloadRow
struct ActiveDownloadRow: View {
    let download: JSActiveDownload
    
    var body: some View {
        HStack {
            // Generic placeholder image since we don't have imageURL in the ActiveDownload
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(download.title ?? download.originalURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                
                // Enhanced progress view
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: download.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .tint(download.progress == 1.0 ? .green : .blue)
                    
                    HStack {
                        Text("\(Int(download.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if download.task.state == .running {
                            Text("Downloading")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else if download.task.state == .suspended {
                            Text("Paused")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding(.leading, 4)
            
            Spacer()
            
            // Download controls - limited for JSController implementation
            Button(action: {
                if download.task.state == .running {
                    download.task.suspend()
                } else if download.task.state == .suspended {
                    download.task.resume()
                }
            }) {
                Image(systemName: download.task.state == .running ? "pause.circle.fill" : "play.circle.fill")
                    .foregroundColor(download.task.state == .running ? .orange : .blue)
                    .font(.title2)
            }
            
            Button(action: {
                download.task.cancel()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - DownloadedAssetRow
struct DownloadedAssetRow: View {
    let asset: DownloadedAsset
    
    var body: some View {
        HStack {
            // Generic placeholder image
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(asset.downloadDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let fileSize = asset.fileSize {
                    Text(formatFileSize(fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 4)
            
            Spacer()
            
            Image(systemName: "play.circle.fill")
                .foregroundColor(.blue)
                .font(.title2)
        }
        .padding(.vertical, 8)
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
