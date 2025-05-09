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
    @EnvironmentObject var jsController: JSController
    @State private var searchText = ""
    @State private var expandedGroups = Set<UUID>()
    @State private var isDeleteModeActive = false
    @State private var showDeleteAlert = false
    @State private var assetToDelete: DownloadedAsset?
    @State private var sortOption: SortOption = .newest
    @State private var currentAsset: DownloadedAsset?
    @State private var selectedTab = 0
    
    // MARK: - Sort Options
    enum SortOption: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case oldest = "Oldest"
        case title = "Title"
        
        var id: String { self.rawValue }
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
        // Verify that the asset file exists before attempting to play
        if !jsController.verifyAssetFileExists(asset) {
            // File doesn't exist and couldn't be found in alternate locations
            // (error is already displayed by verifyAssetFileExists)
            return
        }
        
        currentAsset = asset
        
        // Check if we have a subtitle file for this asset
        if let localSubtitleURL = asset.localSubtitleURL {
            // Use the custom player which supports subtitles
            let dummyMetadata = ModuleMetadata(
                sourceName: "",
                author: ModuleMetadata.Author(name: "", icon: ""),
                iconUrl: "",
                version: "",
                language: "",
                baseUrl: "",
                streamType: "",
                quality: "",
                searchBaseUrl: "",
                scriptUrl: "",
                asyncJS: nil,
                streamAsyncJS: nil,
                softsub: nil,
                multiStream: nil,
                multiSubs: nil,
                type: nil
            )
            
            let dummyModule = ScrapingModule(
                metadata: dummyMetadata,
                localPath: "",
                metadataUrl: ""
            )
            
            let customPlayer = CustomMediaPlayerViewController(
                module: dummyModule,
                urlString: asset.localURL.absoluteString,
                fullUrl: asset.originalURL.absoluteString,
                title: asset.name,
                episodeNumber: asset.metadata?.episode ?? 0,
                onWatchNext: {},
                subtitlesURL: localSubtitleURL.absoluteString,
                aniListID: 0,
                episodeImageUrl: asset.metadata?.posterURL?.absoluteString ?? ""
            )
            
            customPlayer.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            
            // Present the custom player
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(customPlayer, animated: true)
            }
        } else {
            // No subtitle file available, use standard player
            // Create an AVPlayerItem from the local URL
            let playerItem = AVPlayerItem(url: asset.localURL)
            
            // Configure the player
            let player = AVPlayer(playerItem: playerItem)
            
            // Create the controller
            let playerController = AVPlayerViewController()
            playerController.player = player
            
            // Present the player
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(playerController, animated: true) {
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
            // Group header with navigation
            NavigationLink(destination: DownloadedMediaDetailView(group: group)) {
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
                        
                        HStack {
                            Text("\(group.assetCount) \(group.isAnime ? "Episodes" : "Files")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                            Text(formatFileSize(group.totalFileSize))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Group content (episodes or files) when expanded
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
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
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
        HStack(spacing: 8) {
            // Use image from asset metadata if available, otherwise use placeholder
            if let backdropURL = asset.metadata?.backdropURL {
                KFImage(backdropURL)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 40)
                    .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 40)
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.episodeDisplayName)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(asset.downloadDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Show subtitle indicator if subtitles are available
            if asset.localSubtitleURL != nil {
                Image(systemName: "captions.bubble")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            
            Image(systemName: "play.circle.fill")
                .foregroundColor(.blue)
                .font(.title3)
        }
    }
}

// MARK: - DownloadedMediaDetailView
struct DownloadedMediaDetailView: View {
    let group: DownloadGroup
    @StateObject private var jsController = JSController.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isPlaying = false
    @State private var currentAsset: DownloadedAsset?
    @State private var showDeleteAlert = false
    @State private var assetToDelete: DownloadedAsset?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with poster image
                HStack(alignment: .top, spacing: 16) {
                    if let posterURL = group.posterURL {
                        KFImage(posterURL)
                            .placeholder {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 130, height: 195)
                            .cornerRadius(10)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 130, height: 195)
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(2)
                        
                        Text("\(group.assetCount) \(group.isAnime ? "Episodes" : "Files")")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        // Total file size
                        if group.totalFileSize > 0 {
                            Text(formatFileSize(group.totalFileSize))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                
                // Episode list
                VStack(alignment: .leading, spacing: 16) {
                    Text("Episodes")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    let assets = group.isAnime ? group.organizedEpisodes() : group.assets
                    
                    ForEach(assets) { asset in
                        DownloadedEpisodeRow(asset: asset)
                            .padding(.horizontal)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .contextMenu {
                                Button(action: { playAsset(asset) }) {
                                    Label("Play", systemImage: "play.fill")
                                }
                                
                                Button(role: .destructive, action: { confirmDelete(asset) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .onTapGesture {
                                playAsset(asset)
                            }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Downloaded Episodes")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Download", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let asset = assetToDelete {
                    deleteAsset(asset)
                }
            }
        } message: {
            if let asset = assetToDelete {
                Text("Are you sure you want to delete '\(asset.episodeDisplayName)'?")
            } else {
                Text("Are you sure you want to delete this download?")
            }
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func playAsset(_ asset: DownloadedAsset) {
        // Verify that the asset file exists before attempting to play
        if !jsController.verifyAssetFileExists(asset) {
            // File doesn't exist and couldn't be found in alternate locations
            // (error is already displayed by verifyAssetFileExists)
            return
        }
        
        currentAsset = asset
        
        // Check if we have a subtitle file for this asset
        if let localSubtitleURL = asset.localSubtitleURL {
            // Use the custom player which supports subtitles
            let dummyMetadata = ModuleMetadata(
                sourceName: "",
                author: ModuleMetadata.Author(name: "", icon: ""),
                iconUrl: "",
                version: "",
                language: "",
                baseUrl: "",
                streamType: "",
                quality: "",
                searchBaseUrl: "",
                scriptUrl: "",
                asyncJS: nil,
                streamAsyncJS: nil,
                softsub: nil,
                multiStream: nil,
                multiSubs: nil,
                type: nil
            )
            
            let dummyModule = ScrapingModule(
                metadata: dummyMetadata,
                localPath: "",
                metadataUrl: ""
            )
            
            let customPlayer = CustomMediaPlayerViewController(
                module: dummyModule,
                urlString: asset.localURL.absoluteString,
                fullUrl: asset.originalURL.absoluteString,
                title: asset.name,
                episodeNumber: asset.metadata?.episode ?? 0,
                onWatchNext: {},
                subtitlesURL: localSubtitleURL.absoluteString,
                aniListID: 0,
                episodeImageUrl: asset.metadata?.posterURL?.absoluteString ?? ""
            )
            
            customPlayer.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            
            // Present the custom player
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(customPlayer, animated: true)
            }
        } else {
            // No subtitle file available, use standard player
            // Create an AVPlayerItem from the local URL
            let playerItem = AVPlayerItem(url: asset.localURL)
            
            // Configure the player
            let player = AVPlayer(playerItem: playerItem)
            
            // Create the controller
            let playerController = AVPlayerViewController()
            playerController.player = player
            
            // Present the player
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(playerController, animated: true) {
                    player.play()
                }
            }
        }
    }
    
    private func confirmDelete(_ asset: DownloadedAsset) {
        assetToDelete = asset
        showDeleteAlert = true
    }
    
    private func deleteAsset(_ asset: DownloadedAsset) {
        jsController.deleteAsset(asset)
        
        // If we've deleted all episodes in this group, go back
        let remainingAssets = jsController.savedAssets.filter { 
            if asset.type == .episode {
                return $0.metadata?.showTitle == group.title && $0.id != asset.id
            } else {
                return $0.name == group.title && $0.id != asset.id
            }
        }
        
        if remainingAssets.isEmpty {
            dismiss()
        }
    }
}

struct DownloadedEpisodeRow: View {
    let asset: DownloadedAsset
    
    var body: some View {
        HStack(spacing: 12) {
            // Use image from asset metadata if available, otherwise use placeholder
            if let backdropURL = asset.metadata?.backdropURL ?? asset.metadata?.posterURL {
                KFImage(backdropURL)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 68)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 68)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.episodeDisplayName)
                    .font(.headline)
                    .lineLimit(1)
                
                if let fileSize = asset.fileSize {
                    Text(formatFileSize(fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    Text(asset.downloadDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Display subtitle indicator if subtitles are available
                    if asset.localSubtitleURL != nil {
                        Image(systemName: "captions.bubble")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
            }
            
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
