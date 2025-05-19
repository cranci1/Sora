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
import Combine

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
    @State private var viewRefreshTrigger = false
    
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
                if let asset = assetToDelete {
                    Text("Are you sure you want to delete '\(asset.episodeDisplayName)'?")
                } else {
                    Text("Are you sure you want to delete this download?")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("downloadStatusChanged"))) { _ in
                // Force UI refresh when download status changes (especially for mass deletions)
                // This will ensure the view updates when all downloads are cleared
                
                // Force view refresh by clearing any cached file sizes
                DownloadedAsset.clearFileSizeCache()
                DownloadGroup.clearFileSizeCache()
                
                // Reset any expanded groups that might no longer exist
                expandedGroups.removeAll()
                
                // Force the view to refresh with state change
                viewRefreshTrigger.toggle()
            }
            // Force redraw of the view when refresh trigger changes
            .id(viewRefreshTrigger)
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
        
        // Determine the streamType based on the file extension
        let streamType: String
        if asset.localURL.pathExtension.lowercased() == "mp4" {
            streamType = "mp4"
        } else if asset.localURL.absoluteString.contains(".movpkg") {
            streamType = "hls"
        } else {
            streamType = "hls" // Default to HLS if we can't determine
        }
        
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
                streamType: streamType, // Use the determined streamType
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
                episodeImageUrl: asset.metadata?.posterURL?.absoluteString ?? "",
                headers: nil
            )
            
            customPlayer.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            
            // Present the custom player
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(customPlayer, animated: true)
            }
        } else {
            // No subtitle file available, use standard player with appropriate streamType
            let dummyMetadata = ModuleMetadata(
                sourceName: "",
                author: ModuleMetadata.Author(name: "", icon: ""),
                iconUrl: "",
                version: "",
                language: "",
                baseUrl: "",
                streamType: streamType, // Use the determined streamType
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
            
            // Check if we're playing an MP4 file - if so, use the system player for direct playback
            if streamType == "mp4" {
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
            } else {
                // For HLS, use the custom player
                let customPlayer = CustomMediaPlayerViewController(
                    module: dummyModule,
                    urlString: asset.localURL.absoluteString,
                    fullUrl: asset.originalURL.absoluteString,
                    title: asset.name,
                    episodeNumber: asset.metadata?.episode ?? 0,
                    onWatchNext: {},
                    subtitlesURL: nil,
                    aniListID: 0,
                    episodeImageUrl: asset.metadata?.posterURL?.absoluteString ?? "",
                    headers: nil
                )
                
                customPlayer.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                
                // Present the custom player
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(customPlayer, animated: true)
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
    @State private var showDeleteAllAlert = false
    @EnvironmentObject var jsController: JSController
    
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
            .contextMenu {
                Button(action: { onToggleExpand() }) {
                    Label(isExpanded ? "Collapse" : "Expand", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                }
                
                Button(role: .destructive, action: { showDeleteAllAlert = true }) {
                    Label("Delete All Episodes", systemImage: "trash")
                }
            }
            .alert("Delete All Episodes", isPresented: $showDeleteAllAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    deleteAllAssets()
                }
            } message: {
                Text("Are you sure you want to delete all \(group.assetCount) episodes in '\(group.title)'?")
            }
            
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
    
    private func deleteAllAssets() {
        // Delete all assets in this group
        for asset in group.assets {
            jsController.deleteAsset(asset)
        }
        
        // Post notification to refresh the UI
        NotificationCenter.default.post(name: NSNotification.Name("downloadStatusChanged"), object: nil)
    }
}

// MARK: - ActiveDownloadRow
struct ActiveDownloadRow: View {
    let download: JSActiveDownload
    @State private var taskState: URLSessionTask.State
    @State private var currentProgress: Double
    
    init(download: JSActiveDownload) {
        self.download = download
        // Initialize the state from the current task state
        _taskState = State(initialValue: download.task?.state ?? .suspended)
        _currentProgress = State(initialValue: download.progress)
    }
    
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
                    if download.queueStatus == .queued {
                        ProgressView()
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(.orange)
                    } else {
                        ProgressView(value: currentProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(currentProgress == 1.0 ? .green : .blue)
                    }
                    
                    HStack {
                        if download.queueStatus == .queued {
                            Text("Queued")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("\(Int(currentProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if taskState == .running {
                                Text("Downloading")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            } else if taskState == .suspended {
                                Text("Paused")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .padding(.leading, 4)
            
            Spacer()
            
            // Download controls with state tracking
            if download.queueStatus == .queued {
                // Only show cancel button for queued downloads
                Button(action: {
                    // Cancel the queued download
                    JSController.shared.cancelQueuedDownload(download.id)
                    // Post notification for UI updates across the app
                    NotificationCenter.default.post(name: NSNotification.Name("downloadStatusChanged"), object: nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
            } else {
                Button(action: {
                    if taskState == .running {
                        download.task?.suspend()
                        taskState = .suspended
                    } else if taskState == .suspended {
                        download.task?.resume()
                        taskState = .running
                    }
                    // Post notification for UI updates across the app
                    NotificationCenter.default.post(name: NSNotification.Name("downloadStatusChanged"), object: nil)
                }) {
                    Image(systemName: taskState == .running ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundColor(taskState == .running ? .orange : .blue)
                        .font(.title2)
                }
                
                Button(action: {
                    download.task?.cancel()
                    taskState = .canceling
                    // Post notification for UI updates across the app
                    NotificationCenter.default.post(name: NSNotification.Name("downloadStatusChanged"), object: nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
            }
        }
        .onAppear {
            // Update state when view appears
            updateDownloadState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("downloadStatusChanged"))) { _ in
            updateDownloadState()
        }
    }
    
    private func updateDownloadState() {
        // Update task state from the actual download task
        if let task = download.task {
            self.taskState = task.state
        }
        
        // Update progress from the actual download
        self.currentProgress = download.progress
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
                
                HStack(spacing: 4) {
                    Text(asset.downloadDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Show file size
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatFileSize(asset.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Show subtitle indicator if subtitles are available
            if asset.localSubtitleURL != nil {
                Image(systemName: "captions.bubble")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            
            // Show warning if file doesn't exist
            if !asset.fileExists {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
            
            Image(systemName: "play.circle.fill")
                .foregroundColor(asset.fileExists ? .blue : .gray)
                .font(.title3)
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
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
    @State private var showDeleteAllAlert = false
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
                    HStack {
                        Text("Episodes")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            showDeleteAllAlert = true
                        }) {
                            Label("Delete All", systemImage: "trash")
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                    
                    let assets = group.isAnime ? group.organizedEpisodes() : group.assets
                    
                    if assets.isEmpty {
                        Text("No episodes available")
                            .foregroundColor(.gray)
                            .italic()
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
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
        .alert("Delete All Episodes", isPresented: $showDeleteAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllAssets()
            }
        } message: {
            Text("Are you sure you want to delete all episodes in '\(group.title)'?")
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
        
        // Determine the streamType based on the file extension
        let streamType: String
        if asset.localURL.pathExtension.lowercased() == "mp4" {
            streamType = "mp4"
        } else if asset.localURL.absoluteString.contains(".movpkg") {
            streamType = "hls"
        } else {
            streamType = "hls" // Default to HLS if we can't determine
        }
        
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
                streamType: streamType, // Use the determined streamType
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
                episodeImageUrl: asset.metadata?.posterURL?.absoluteString ?? "",
                headers: nil
            )
            
            customPlayer.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            
            // Present the custom player
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(customPlayer, animated: true)
            }
        } else {
            // No subtitle file available, use standard player with appropriate streamType
            let dummyMetadata = ModuleMetadata(
                sourceName: "",
                author: ModuleMetadata.Author(name: "", icon: ""),
                iconUrl: "",
                version: "",
                language: "",
                baseUrl: "",
                streamType: streamType, // Use the determined streamType
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
            
            // Check if we're playing an MP4 file - if so, use the system player for direct playback
            if streamType == "mp4" {
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
            } else {
                // For HLS, use the custom player
                let customPlayer = CustomMediaPlayerViewController(
                    module: dummyModule,
                    urlString: asset.localURL.absoluteString,
                    fullUrl: asset.originalURL.absoluteString,
                    title: asset.name,
                    episodeNumber: asset.metadata?.episode ?? 0,
                    onWatchNext: {},
                    subtitlesURL: nil,
                    aniListID: 0,
                    episodeImageUrl: asset.metadata?.posterURL?.absoluteString ?? "",
                    headers: nil
                )
                
                customPlayer.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                
                // Present the custom player
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(customPlayer, animated: true)
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
        
        // DO NOT dismiss the view when all assets are deleted
        // Let the user navigate back manually
    }
    
    private func deleteAllAssets() {
        // Delete all assets in this group
        for asset in group.assets {
            jsController.deleteAsset(asset)
        }
        
        // Post notification to refresh the UI
        NotificationCenter.default.post(name: NSNotification.Name("downloadStatusChanged"), object: nil)
        
        // DO NOT dismiss the view - let the user navigate back manually
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
                
                // Always show file size (will be zero if file doesn't exist)
                Text(formatFileSize(asset.fileSize))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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
                    
                    // Show warning if file doesn't exist
                    if !asset.fileExists {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "play.circle.fill")
                .foregroundColor(asset.fileExists ? .blue : .gray)
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
