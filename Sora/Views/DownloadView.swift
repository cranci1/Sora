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
    @State private var expandedGroups: Set<UUID> = []
    
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
        ScrollView {
            LazyVStack(spacing: 12) {
                // Group active downloads by anime title
                ForEach(groupActiveDownloads().keys.sorted(), id: \.self) { title in
                    if let downloads = groupActiveDownloads()[title] {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(title)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(downloads) { download in
                                ActiveDownloadRow(download: download)
                                    .padding(.horizontal)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Downloaded Content List
    private var downloadedContentList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let groups = filterAndGroupAssets()
                
                ForEach(groups) { group in
                    DownloadGroupView(
                        group: group, 
                        isExpanded: expandedGroups.contains(group.id),
                        onDelete: confirmDelete,
                        onPlay: playAsset,
                        onToggleExpand: { toggleGroup(group.id) }
                    )
                }
            }
            .padding()
        }
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
    
    private func toggleGroup(_ id: UUID) {
        if expandedGroups.contains(id) {
            expandedGroups.remove(id)
        } else {
            expandedGroups.insert(id)
        }
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
    private func filterAndGroupAssets() -> [DownloadGroup] {
        let filteredAssets = searchText.isEmpty
            ? jsController.savedAssets
            : jsController.savedAssets.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.metadata?.showTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        
        let sortedAssets: [DownloadedAsset]
        switch sortOption {
        case .newest:
            sortedAssets = filteredAssets.sorted { $0.downloadDate > $1.downloadDate }
        case .oldest:
            sortedAssets = filteredAssets.sorted { $0.downloadDate < $1.downloadDate }
        case .title:
            sortedAssets = filteredAssets.sorted { $0.name < $1.name }
        }
        
        return sortedAssets.groupedByTitle()
    }
    
    private func groupActiveDownloads() -> [String: [JSActiveDownload]] {
        // Group JSActiveDownload objects by anime title from metadata
        let groupedDict = Dictionary(grouping: jsController.activeDownloads) { download in
            // Prioritize showTitle from metadata for episodes
            if let metadata = download.metadata, 
               let showTitle = metadata.showTitle, 
               !showTitle.isEmpty {
                return showTitle
            }
            // Fallback to title or URL
            return download.title ?? download.originalURL.lastPathComponent
        }
        return groupedDict
    }
}

// MARK: - DownloadGroupView
struct DownloadGroupView: View {
    let group: DownloadGroup
    let isExpanded: Bool
    let onDelete: (DownloadedAsset) -> Void
    let onPlay: (DownloadedAsset) -> Void
    let onToggleExpand: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Group header
            Button(action: onToggleExpand) {
                HStack {
                    if let posterURL = group.posterURL {
                        KFImage(posterURL)
                            .placeholder {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 75)
                            .cornerRadius(6)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 75)
                            .cornerRadius(6)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(group.title)
                            .font(.headline)
                        
                        Text("\(group.assetCount) \(group.isAnime ? "Episodes" : "Files")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Group content (episodes or files)
            if isExpanded {
                VStack(spacing: 4) {
                    let assets = group.isAnime ? group.organizedEpisodes() : group.assets
                    
                    ForEach(assets) { asset in
                        DownloadedAssetRow(asset: asset)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(8)
                            .contextMenu {
                                Button(role: .destructive, action: { onDelete(asset) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .onTapGesture {
                                onPlay(asset)
                            }
                    }
                }
                .padding(.leading, 12)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

// MARK: - ActiveDownloadRow
struct ActiveDownloadRow: View {
    let download: JSActiveDownload
    
    var body: some View {
        HStack {
            // Use the imageURL from the download if available
            if let imageURL = download.imageURL {
                KFImage(imageURL)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            } else {
                // Fallback to placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            }
            
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
    }
}

// MARK: - DownloadedAssetRow
struct DownloadedAssetRow: View {
    let asset: DownloadedAsset
    
    var body: some View {
        HStack {
            // Use KFImage to load the actual image from metadata if available
            if let posterURL = asset.metadata?.posterURL {
                KFImage(posterURL)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            } else {
                // Fallback to placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.type == .episode ? asset.episodeDisplayName : asset.name)
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
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
