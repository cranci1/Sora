//
//  DownloadView.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import SwiftUI
import AVKit
import Kingfisher

struct DownloadView: View {
    @EnvironmentObject var jsController: JSController
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var sortOption: SortOption = .newest
    @State private var showDeleteAlert = false
    @State private var assetToDelete: DownloadedAsset?
    
    enum SortOption: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case oldest = "Oldest"
        case title = "Title"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Download Status", selection: $selectedTab) {
                    Text("Active").tag(0)
                    Text("Downloaded").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Content
                if selectedTab == 0 {
                    activeDownloadsView
                    } else {
                    downloadedContentView
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
                }
            }
                }
            }
    
    // MARK: - Active Downloads View
    private var activeDownloadsView: some View {
        Group {
            if jsController.activeDownloads.isEmpty {
                emptyActiveDownloadsView
            } else {
        ScrollView {
            LazyVStack(spacing: 12) {
                        ForEach(jsController.activeDownloads) { download in
                            ActiveDownloadCard(download: download)
                                    .padding(.horizontal)
                            }
                        }
                    .padding(.vertical)
                }
            }
        }
    }
    
    // MARK: - Downloaded Content View
    private var downloadedContentView: some View {
        Group {
            if filteredAndSortedAssets.isEmpty {
                emptyDownloadsView
            } else {
        ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(groupedAssets, id: \.title) { group in
                            DownloadGroupCard(
                        group: group, 
                                onDelete: { asset in
                                    assetToDelete = asset
                                    showDeleteAlert = true
                                },
                                onPlay: playAsset
                            )
                            .padding(.horizontal)
                }
            }
                    .padding(.vertical)
                }
            }
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
    
    // MARK: - Data Processing
    private var filteredAndSortedAssets: [DownloadedAsset] {
        let filtered = searchText.isEmpty 
            ? jsController.savedAssets
            : jsController.savedAssets.filter { asset in
                asset.name.localizedCaseInsensitiveContains(searchText) ||
                (asset.metadata?.showTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        
        switch sortOption {
        case .newest:
            return filtered.sorted { $0.downloadDate > $1.downloadDate }
        case .oldest:
            return filtered.sorted { $0.downloadDate < $1.downloadDate }
        case .title:
            return filtered.sorted { $0.name < $1.name }
        }
    }
    
    private var groupedAssets: [SimpleDownloadGroup] {
        let grouped = Dictionary(grouping: filteredAndSortedAssets) { asset in
            asset.metadata?.showTitle ?? asset.name
        }
        
        return grouped.map { title, assets in
            SimpleDownloadGroup(
                title: title,
                assets: assets,
                posterURL: assets.first?.metadata?.posterURL
            )
        }.sorted { $0.title < $1.title }
    }
    
    // MARK: - Actions
    private func playAsset(_ asset: DownloadedAsset) {
        // Verify file exists
        guard jsController.verifyAssetFileExists(asset) else { return }
        
        // Determine stream type
        let streamType = asset.localURL.pathExtension.lowercased() == "mp4" ? "mp4" : "hls"
        
        // Create dummy metadata for player
            let dummyMetadata = ModuleMetadata(
                sourceName: "",
                author: ModuleMetadata.Author(name: "", icon: ""),
                iconUrl: "",
                version: "",
                language: "",
                baseUrl: "",
            streamType: streamType,
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
            
        // Present player
            if streamType == "mp4" {
            // Use system player for MP4
                let playerItem = AVPlayerItem(url: asset.localURL)
                let player = AVPlayer(playerItem: playerItem)
                let playerController = AVPlayerViewController()
                playerController.player = player
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(playerController, animated: true) {
                        player.play()
                    }
                }
            } else {
            // Use custom player for HLS
                let customPlayer = CustomMediaPlayerViewController(
                    module: dummyModule,
                    urlString: asset.localURL.absoluteString,
                    fullUrl: asset.originalURL.absoluteString,
                    title: asset.name,
                    episodeNumber: asset.metadata?.episode ?? 0,
                    onWatchNext: {},
                subtitlesURL: asset.localSubtitleURL?.absoluteString,
                    aniListID: 0,
                    episodeImageUrl: asset.metadata?.posterURL?.absoluteString ?? "",
                    headers: nil
                )
                
                customPlayer.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(customPlayer, animated: true)
                }
            }
        }
    }
    
// MARK: - Supporting Types
struct SimpleDownloadGroup {
    let title: String
    let assets: [DownloadedAsset]
    let posterURL: URL?
    
    var assetCount: Int { assets.count }
    var totalFileSize: Int64 {
        // Simple summation without complex caching to avoid navigation issues
        assets.reduce(0) { $0 + $1.fileSize }
    }
}

// MARK: - ActiveDownloadCard
struct ActiveDownloadCard: View {
    let download: JSActiveDownload
    @State private var currentProgress: Double
    @State private var taskState: URLSessionTask.State
    
    init(download: JSActiveDownload) {
        self.download = download
        _currentProgress = State(initialValue: download.progress)
        _taskState = State(initialValue: download.task?.state ?? .suspended)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let imageURL = download.imageURL {
                KFImage(imageURL)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(download.title ?? download.originalURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                
                // Progress
                VStack(alignment: .leading, spacing: 4) {
                    if download.queueStatus == .queued {
                        ProgressView()
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(.orange)
                    } else {
                        ProgressView(value: currentProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(currentProgress >= 1.0 ? .green : .blue)
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
                        }
                            
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
            
            Spacer()
            
            // Controls
            HStack(spacing: 8) {
            if download.queueStatus == .queued {
                    Button(action: cancelDownload) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
            } else {
                    Button(action: toggleDownload) {
                    Image(systemName: taskState == .running ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundColor(taskState == .running ? .orange : .blue)
                        .font(.title2)
                }
                
                    Button(action: cancelDownload) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
            }
        }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("downloadProgressChanged"))) { _ in
            updateProgress()
        }
    }
    
    private func updateProgress() {
        if let currentDownload = JSController.shared.activeDownloads.first(where: { $0.id == download.id }) {
            withAnimation(.easeInOut(duration: 0.1)) {
                currentProgress = currentDownload.progress
            }
            if let task = currentDownload.task {
                taskState = task.state
            }
        }
    }
    
    private func toggleDownload() {
        if taskState == .running {
            download.task?.suspend()
            taskState = .suspended
        } else if taskState == .suspended {
            download.task?.resume()
            taskState = .running
        }
    }
    
    private func cancelDownload() {
        if download.queueStatus == .queued {
            JSController.shared.cancelQueuedDownload(download.id)
        } else {
            download.task?.cancel()
        }
    }
}

// MARK: - DownloadGroupCard
struct DownloadGroupCard: View {
    let group: SimpleDownloadGroup
    let onDelete: (DownloadedAsset) -> Void
    let onPlay: (DownloadedAsset) -> Void
    
    var body: some View {
        NavigationLink(destination: ShowEpisodesView(group: group, onDelete: onDelete, onPlay: onPlay)) {
            HStack(spacing: 12) {
                // Poster
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
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text("\(group.assetCount) Episodes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(formatFileSize(group.totalFileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Navigation chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - EpisodeRow
struct EpisodeRow: View {
    let asset: DownloadedAsset
    let onDelete: () -> Void
    let onPlay: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let backdropURL = asset.metadata?.backdropURL {
                KFImage(backdropURL)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 40)
                    .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 40)
                    .cornerRadius(6)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.episodeDisplayName)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(asset.downloadDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
            if asset.localSubtitleURL != nil {
                Image(systemName: "captions.bubble")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            
            if !asset.fileExists {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(.caption)
                    }
                }
            }
            
            Spacer()
            
            // Play button
            Button(action: onPlay) {
            Image(systemName: "play.circle.fill")
                .foregroundColor(asset.fileExists ? .blue : .gray)
                .font(.title3)
        }
            .disabled(!asset.fileExists)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
        .contextMenu {
            Button(action: onPlay) {
                Label("Play", systemImage: "play.fill")
            }
            .disabled(!asset.fileExists)
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - ShowEpisodesView
struct ShowEpisodesView: View {
    let group: SimpleDownloadGroup
    let onDelete: (DownloadedAsset) -> Void
    let onPlay: (DownloadedAsset) -> Void
    @State private var showDeleteAlert = false
    @State private var showDeleteAllAlert = false
    @State private var assetToDelete: DownloadedAsset?
    @EnvironmentObject var jsController: JSController
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with poster and info
                HStack(alignment: .top, spacing: 16) {
                    // Larger poster image
                    if let posterURL = group.posterURL {
                        KFImage(posterURL)
                            .placeholder {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 180)
                            .cornerRadius(10)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 180)
                            .cornerRadius(10)
                    }
                    
                    // Show info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(3)
                        
                        Text("\(group.assetCount) Episodes")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                            Text(formatFileSize(group.totalFileSize))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                
                // Episodes section
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
                    
                    // Episodes list
                    if group.assets.isEmpty {
                        Text("No episodes available")
                            .foregroundColor(.gray)
                            .italic()
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(group.assets) { asset in
                                DetailedEpisodeRow(asset: asset)
                                .padding(.horizontal)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .padding(.horizontal)
                                .contextMenu {
                                        Button(action: { onPlay(asset) }) {
                                        Label("Play", systemImage: "play.fill")
                                    }
                                        .disabled(!asset.fileExists)
                                    
                                        Button(role: .destructive, action: { 
                                            assetToDelete = asset
                                            showDeleteAlert = true
                                        }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .onTapGesture {
                                        onPlay(asset)
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Episodes")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Episode", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let asset = assetToDelete {
                    onDelete(asset)
                }
            }
        } message: {
            if let asset = assetToDelete {
                Text("Are you sure you want to delete '\(asset.episodeDisplayName)'?")
            }
        }
        .alert("Delete All Episodes", isPresented: $showDeleteAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllAssets()
            }
        } message: {
            Text("Are you sure you want to delete all \(group.assetCount) episodes in '\(group.title)'?")
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func deleteAllAssets() {
        for asset in group.assets {
            jsController.deleteAsset(asset)
        }
    }
}

// MARK: - DetailedEpisodeRow
struct DetailedEpisodeRow: View {
    let asset: DownloadedAsset
    
    var body: some View {
        HStack(spacing: 12) {
            // Episode thumbnail
            if let backdropURL = asset.metadata?.backdropURL ?? asset.metadata?.posterURL {
                KFImage(backdropURL)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 60)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 60)
                    .cornerRadius(8)
            }
            
            // Episode info
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.episodeDisplayName)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(formatFileSize(asset.fileSize))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    Text(asset.downloadDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if asset.localSubtitleURL != nil {
                        Image(systemName: "captions.bubble")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                    
                    if !asset.fileExists {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
            }
            
            Spacer()
            
            // Play button
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

