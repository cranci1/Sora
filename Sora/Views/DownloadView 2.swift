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
    @StateObject private var viewModel = DownloadManager.shared
    @State private var selectedTab = 0
    @State private var showDeleteAlert = false
    @State private var episodeToDelete: DownloadedEpisode?
    @State private var searchText = ""
    @State private var sortOption: SortOption = .newest
    
    enum SortOption {
        case newest, oldest, title, episodeNumber
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Tab selector for Active/Queued/Completed
                Picker("Download Status", selection: $selectedTab) {
                    Text("Active").tag(0)
                    Text("Queued").tag(1)
                    Text("Downloaded").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if selectedTab == 0 {
                    // ACTIVE DOWNLOADS
                    if viewModel.activeDownloads.isEmpty {
                        emptyActiveDownloadsView
                    } else {
                        activeDownloadsList
                    }
                } else if selectedTab == 1 {
                    // QUEUED DOWNLOADS
                    if viewModel.queuedDownloads.isEmpty {
                        emptyQueuedDownloadsView
                    } else {
                        queuedDownloadsList
                    }
                } else {
                    // DOWNLOADED CONTENT
                    if viewModel.savedEpisodes.isEmpty {
                        emptyDownloadsView
                    } else {
                        downloadedContentList
                    }
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                if selectedTab == 2 && !viewModel.savedEpisodes.isEmpty {
                    Menu {
                        Button("Sort by Newest") { sortOption = .newest }
                        Button("Sort by Oldest") { sortOption = .oldest }
                        Button("Sort by Title") { sortOption = .title }
                        Button("Sort by Episode Number") { sortOption = .episodeNumber }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                
                if selectedTab == 1 && !viewModel.queuedDownloads.isEmpty {
                    Button(action: {
                        viewModel.clearQueue()
                    }) {
                        Image(systemName: "trash")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search downloads")
            .alert("Delete Download", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let episode = episodeToDelete {
                        viewModel.deleteEpisode(episode)
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
            ForEach(viewModel.activeDownloads) { download in
                ActiveDownloadRow(download: download)
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Queued Downloads List
    private var queuedDownloadsList: some View {
        List {
            ForEach(viewModel.queuedDownloads) { episode in
                QueuedDownloadRow(episode: episode)
                    .contextMenu {
                        Button(action: { viewModel.moveUpInQueue(episode) }) {
                            Label("Move Up", systemImage: "arrow.up")
                        }
                        Button(action: { viewModel.moveDownInQueue(episode) }) {
                            Label("Move Down", systemImage: "arrow.down")
                        }
                        Button(role: .destructive, action: { viewModel.removeFromQueue(episode) }) {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Downloaded Content List
    private var downloadedContentList: some View {
        List {
            ForEach(groupDownloadsByModule()) { group in
                Section(header: Text(group.module)) {
                    ForEach(filterAndSortEpisodes(group.episodes)) { episode in
                        DownloadedEpisodeRow(episode: episode)
                            .contextMenu {
                                Button(role: .destructive, action: { confirmDelete(episode) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .onTapGesture {
                                playEpisode(episode)
                            }
                    }
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
    
    private var emptyQueuedDownloadsView: some View {
        VStack {
            Image(systemName: "list.bullet")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding()
            
            Text("No Queued Downloads")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("Episodes you queue for download will appear here")
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
            
            Text("Your downloaded episodes will appear here")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    private func confirmDelete(_ episode: DownloadedEpisode) {
        episodeToDelete = episode
        showDeleteAlert = true
    }
    
    private func playEpisode(_ episode: DownloadedEpisode) {
        // Create a player view controller for the downloaded file
        let moduleManager = ModuleManager()
        moduleManager.loadModules()
        
        if UserDefaults.standard.string(forKey: "externalPlayer") == "Default" {
            // First, we need to find the module object using the moduleType string
            if let module = moduleManager.modules.first(where: { $0.metadata.sourceName == episode.moduleType }) {
                let videoPlayerViewController = VideoPlayerViewController(module: module)
                videoPlayerViewController.useOfflinePlayback = true
                videoPlayerViewController.offlineURL = episode.localURL
                videoPlayerViewController.episodeImageUrl = episode.imageURL?.absoluteString ?? ""
                videoPlayerViewController.episodeNumber = episode.episodeNumber
                videoPlayerViewController.mediaTitle = episode.title
                videoPlayerViewController.aniListID = episode.aniListID ?? 0
                videoPlayerViewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    findTopViewController.findViewController(rootVC).present(videoPlayerViewController, animated: true, completion: nil)
                }
            }
        } else {
            // First, we need to find the module object using the moduleType string
            if let module = moduleManager.modules.first(where: { $0.metadata.sourceName == episode.moduleType }) {
                let customMediaPlayer = CustomMediaPlayerViewController(
                    module: module,
                    urlString: episode.localURL.absoluteString,
                    fullUrl: episode.originalURL.absoluteString,
                    title: episode.title,
                    episodeNumber: episode.episodeNumber,
                    onWatchNext: { },
                    subtitlesURL: nil,
                    aniListID: episode.aniListID ?? 0,
                    episodeImageUrl: episode.imageURL?.absoluteString ?? "",
                    useOfflinePlayback: true
                )
                customMediaPlayer.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    findTopViewController.findViewController(rootVC).present(customMediaPlayer, animated: true, completion: nil)
                }
            }
        }
    }
    
    // MARK: - Data Organization
    struct ModuleGroup: Identifiable {
        let id = UUID()
        let module: String
        let episodes: [DownloadedEpisode]
    }
    
    private func groupDownloadsByModule() -> [ModuleGroup] {
        let groupedByModule = Dictionary(grouping: viewModel.savedEpisodes) { $0.moduleType }
        
        return groupedByModule.map { module, episodes in
            ModuleGroup(module: module, episodes: episodes)
        }.sorted { $0.module < $1.module }
    }
    
    private func filterAndSortEpisodes(_ episodes: [DownloadedEpisode]) -> [DownloadedEpisode] {
        let filteredEpisodes = searchText.isEmpty
            ? episodes
            : episodes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        
        switch sortOption {
        case .newest:
            return filteredEpisodes.sorted { $0.downloadDate > $1.downloadDate }
        case .oldest:
            return filteredEpisodes.sorted { $0.downloadDate < $1.downloadDate }
        case .title:
            return filteredEpisodes.sorted { $0.title < $1.title }
        case .episodeNumber:
            return filteredEpisodes.sorted { $0.episodeNumber < $1.episodeNumber }
        }
    }
}

// MARK: - ActiveDownloadRow
struct ActiveDownloadRow: View {
    let download: ActiveDownload
    @ObservedObject private var downloadManager = DownloadManager.shared
    
    var body: some View {
        HStack {
            if let imageURL = download.imageURL {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(download.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("Episode \(download.episodeNumber)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
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
                        
                        if let task = download.task {
                            if task.state == .suspended {
                                Text("Paused")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else if task.state == .running {
                                Text("Downloading")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .padding(.leading, 4)
            
            Spacer()
            
            // Enhanced download controls
            HStack(spacing: 8) {
                if let task = download.task {
                    if task.state == .running {
                        Button(action: {
                            downloadManager.pauseDownload(download)
                        }) {
                            Image(systemName: "pause.circle.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                        }
                    } else if task.state == .suspended {
                        Button(action: {
                            downloadManager.resumeDownload(download)
                        }) {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                    }
                }
                
                Button(action: {
                    downloadManager.cancelDownload(download)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .contextMenu {
            if let task = download.task {
                if task.state == .running {
                    Button(action: { downloadManager.pauseDownload(download) }) {
                        Label("Pause", systemImage: "pause")
                    }
                } else if task.state == .suspended {
                    Button(action: { downloadManager.resumeDownload(download) }) {
                        Label("Resume", systemImage: "play")
                    }
                }
            }
            
            Button(role: .destructive, action: { downloadManager.cancelDownload(download) }) {
                Label("Cancel", systemImage: "xmark")
            }
        }
    }
}

// MARK: - DownloadedEpisodeRow
struct DownloadedEpisodeRow: View {
    let episode: DownloadedEpisode
    
    var body: some View {
        HStack {
            if let imageURL = episode.imageURL {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("Episode \(episode.episodeNumber)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let fileSize = episode.fileSize {
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

// MARK: - QueuedDownloadRow
struct QueuedDownloadRow: View {
    let episode: DownloadableEpisode
    
    var body: some View {
        HStack {
            if let imageURL = episode.imageURL {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("Episode \(episode.episodeNumber)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Queued")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding(.leading, 4)
            
            Spacer()
            
            Image(systemName: "clock")
                .foregroundColor(.gray)
                .font(.title2)
        }
        .padding(.vertical, 8)
    }
}
