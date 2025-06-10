//
//  DownloadView.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import AVKit
import NukeUI
import SwiftUI

struct DownloadView: View {
    @EnvironmentObject var jsController: JSController
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var sortOption: SortOption = .newest
    @State private var showDeleteAlert = false
    @State private var assetToDelete: DownloadedAsset?
    @State private var isSearchActive = false
    
    enum SortOption: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case oldest = "Oldest"
        case title = "Title"
        
        var id: String { self.rawValue }
        
        var systemImage: String {
            switch self {
            case .newest: return "calendar.badge.clock"
            case .oldest: return "calendar"
            case .title: return "textformat.abc"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 20)
                CustomDownloadHeader(
                    selectedTab: $selectedTab,
                    searchText: $searchText,
                    isSearchActive: $isSearchActive,
                    sortOption: $sortOption,
                    showSortMenu: selectedTab == 1 && !jsController.savedAssets.isEmpty
                )
                
                if selectedTab == 0 {
                    activeDownloadsView
                        .transition(.opacity)
                } else {
                    downloadedContentView
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            .navigationBarHidden(true)
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
        .deviceScaled()
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var activeDownloadsView: some View {
        Group {
            if jsController.activeDownloads.isEmpty && jsController.downloadQueue.isEmpty {
                emptyActiveDownloadsView
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        if !jsController.downloadQueue.isEmpty {
                            DownloadSectionView(
                                title: "Queue",
                                icon: "clock.fill",
                                downloads: jsController.downloadQueue
                            )
                        }
                        
                        if !jsController.activeDownloads.isEmpty {
                            DownloadSectionView(
                                title: "Active Downloads",
                                icon: "arrow.down.circle.fill",
                                downloads: jsController.activeDownloads
                            )
                        }
                    }
                    .padding(.top, 20)
                    .scrollViewBottomPadding()
                }
            }
        }
    }
    
    private var downloadedContentView: some View {
        Group {
            if filteredAndSortedAssets.isEmpty {
                emptyDownloadsView
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        DownloadSummaryCard(
                            totalShows: groupedAssets.count,
                            totalEpisodes: filteredAndSortedAssets.count,
                            totalSize: filteredAndSortedAssets.reduce(0) { $0 + $1.fileSize }
                        )
                        
                        DownloadedSection(
                            groups: groupedAssets,
                            onDelete: { asset in
                                assetToDelete = asset
                                showDeleteAlert = true
                            },
                            onPlay: playAsset
                        )
                    }
                    .padding(.top, 20)
                    .scrollViewBottomPadding()
                }
            }
        }
    }
    
    private var emptyActiveDownloadsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text("No Active Downloads")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text("Actively downloading media can be tracked from here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 40)
    }
    
    private var emptyDownloadsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text("No Downloads")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text("Your downloaded episodes will appear here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 40)
    }
    
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
                posterURL: assets.first?.metadata?.showPosterURL
                          ?? assets.first?.metadata?.posterURL
            )
        }.sorted { $0.title < $1.title }
    }
    
    private func playAsset(_ asset: DownloadedAsset) {
        guard jsController.verifyAssetFileExists(asset) else { return }
        
        let streamType = asset.localURL.pathExtension.lowercased() == "mp4" ? "mp4" : "hls"
        
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
        
        // Always use CustomMediaPlayerViewController for consistency
        let customPlayer = CustomMediaPlayerViewController(
            module: dummyModule,
            urlString: asset.localURL.absoluteString,
            fullUrl: asset.originalURL.absoluteString,
            title: asset.metadata?.showTitle ?? asset.name,
            episodeNumber: asset.metadata?.episode ?? 0,
            onWatchNext: {},
            subtitlesURL: asset.localSubtitleURL?.absoluteString,
            aniListID: 0,
            totalEpisodes: asset.metadata?.episode ?? 0,
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

struct CustomDownloadHeader: View {
    @Binding var selectedTab: Int
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    @Binding var sortOption: DownloadView.SortOption
    let showSortMenu: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Downloads")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSearchActive.toggle()
                        }
                        if !isSearchActive {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: isSearchActive ? "xmark.circle.fill" : "magnifyingglass")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.accentColor)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .shadow(color: .accentColor.opacity(0.2), radius: 2)
                            )
                            .circularGradientOutline()
                    }

                    if showSortMenu {
                        Menu {
                            ForEach(DownloadView.SortOption.allCases) { option in
                                Button(action: { sortOption = option }) {
                                    HStack {
                                        Image(systemName: option.systemImage)
                                        Text(option.rawValue)
                                        if sortOption == option {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundColor(.accentColor)
                                .padding(10)
                                .background(
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .shadow(color: .accentColor.opacity(0.2), radius: 2)
                                )
                                .circularGradientOutline()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)
            .padding(.bottom, isSearchActive ? 12 : 8)
            
            if isSearchActive {
                HStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.secondary)
                        
                        TextField("Search downloads", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.primary)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: Color.accentColor.opacity(0.25), location: 0),
                                                .init(color: Color.accentColor.opacity(0), location: 1)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1.5
                                    )
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    TabButton(
                        title: "Active",
                        icon: "arrow.down.circle",
                        isSelected: selectedTab == 0,
                        action: { selectedTab = 0 }
                    )
                    
                    TabButton(
                        title: "Downloaded",
                        icon: "checkmark.circle",
                        isSelected: selectedTab == 1,
                        action: { selectedTab = 1 }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.accentColor.opacity(0.25), location: 0),
                                        .init(color: Color.accentColor.opacity(0), location: 1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            : AnyShapeStyle(Color.clear),
                        lineWidth: 1.5
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct SimpleDownloadGroup {
    let title: String
    let assets: [DownloadedAsset]
    let posterURL: URL?
    
    var assetCount: Int { assets.count }
    var totalFileSize: Int64 {
        assets.reduce(0) { $0 + $1.fileSize }
    }
}

struct DownloadSectionView: View {
    let title: String
    let icon: String
    let downloads: [JSActiveDownload]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title.uppercased())
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 8) {
                ForEach(downloads) { download in
                    EnhancedActiveDownloadCard(download: download)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
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
        }
    }
}

struct DownloadSummaryCard: View {
    let totalShows: Int
    let totalEpisodes: Int
    let totalSize: Int64

    var body: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .foregroundColor(.accentColor)
            Text("Download Summary".uppercased())
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, -6)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 20) {
                SummaryItem(
                    title: "Shows",
                    value: "\(totalShows)",
                    icon: "tv.fill"
                )

                Divider().frame(height: 32)

                SummaryItem(
                    title: "Episodes",
                    value: "\(totalEpisodes)",
                    icon: "play.rectangle.fill"
                )

                Divider().frame(height: 32)

                let formattedSize = formatFileSize(totalSize)
                let components = formattedSize.split(separator: " ")
                let sizeValue = components.first.map(String.init) ?? formattedSize
                let sizeUnit = components.dropFirst().first.map(String.init) ?? ""

                SummaryItem(
                    title: "Size (\(sizeUnit))",
                    value: sizeValue,
                    icon: "internaldrive.fill"
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
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
    }

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func formatFileSizeWithUnit(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file

        let formattedString = formatter.string(fromByteCount: size)
        let components = formattedString.components(separatedBy: " ")
        if components.count == 2 {
            return "Size (\(components[1]))"
        }
        return "Size"
    }


struct SummaryItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            if !value.isEmpty {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DownloadedSection: View {
    let groups: [SimpleDownloadGroup]
    let onDelete: (DownloadedAsset) -> Void
    let onPlay: (DownloadedAsset) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                Text("Downloaded Shows".uppercased())
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 8) {
                ForEach(groups, id: \.title) { group in
                    EnhancedDownloadGroupCard(
                        group: group,
                        onDelete: onDelete,
                        onPlay: onPlay
                    )
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
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
        }
    }
}

struct EnhancedActiveDownloadCard: View {
    let download: JSActiveDownload
    @State private var currentProgress: Double
    @State private var taskState: URLSessionTask.State
    
    init(download: JSActiveDownload) {
        self.download = download
        _currentProgress = State(initialValue: download.progress)
        _taskState = State(initialValue: download.taskState)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Group {
                    if let imageURL = download.imageURL {
                        LazyImage(url: imageURL) { state in
                            if let uiImage = state.imageContainer?.image {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle()
                                    .fill(.tertiary)
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(.tertiary)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(download.title ?? download.originalURL.lastPathComponent)
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    
                    VStack(spacing: 6) {
                        HStack {
                            if download.queueStatus == .queued {
                                Text("Queued")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.orange)
                            } else {
                                Text("\(Int(currentProgress * 100))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 6, height: 6)
                                
                                Text(statusText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if download.queueStatus == .queued {
                            ProgressView()
                                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                                .scaleEffect(y: 0.8)
                        } else {
                            ProgressView(value: currentProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: currentProgress >= 1.0 ? .green : .accentColor))
                                .scaleEffect(y: 0.8)
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    if download.queueStatus == .queued {
                        Button(action: cancelDownload) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                        }
                    } else {
                        Button(action: toggleDownload) {
                            Image(systemName: taskState == .running ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title3)
                                .foregroundStyle(taskState == .running ? .orange : .accentColor)
                        }
                        
                        Button(action: cancelDownload) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(16)
            
            if download != download {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("downloadProgressChanged"))) { _ in
            updateProgress()
        }
    }
    
    private var statusColor: Color {
        if download.queueStatus == .queued {
            return .orange
        } else if taskState == .running {
            return .green
        } else {
            return .orange
        }
    }
    
    private var statusText: String {
        if download.queueStatus == .queued {
            return "Queued"
        } else if taskState == .running {
            return "Downloading"
        } else {
            return "Paused"
        }
    }
    
    private func updateProgress() {
        if let currentDownload = JSController.shared.activeDownloads.first(where: { $0.id == download.id }) {
            withAnimation(.easeInOut(duration: 0.1)) {
                currentProgress = currentDownload.progress
            }
            taskState = currentDownload.taskState
        }
    }
    
    private func toggleDownload() {
        if taskState == .running {
            // Pause the download
            if download.task != nil {
                // M3U8 download - use AVAssetDownloadTask
                download.underlyingTask?.suspend()
            } else if download.urlSessionTask != nil {
                // MP4 download - use dedicated method
                JSController.shared.pauseMP4Download(download.id)
            }
            taskState = .suspended
        } else if taskState == .suspended {
            // Resume the download
            if download.task != nil {
                // M3U8 download - use AVAssetDownloadTask
                download.underlyingTask?.resume()
            } else if download.urlSessionTask != nil {
                // MP4 download - use dedicated method
                JSController.shared.resumeMP4Download(download.id)
            }
            taskState = .running
        }
    }
    
    private func cancelDownload() {
        if download.queueStatus == .queued {
            JSController.shared.cancelQueuedDownload(download.id)
        } else {
            JSController.shared.cancelActiveDownload(download.id)
        }
    }
}

struct EnhancedDownloadGroupCard: View {
    let group: SimpleDownloadGroup
    let onDelete: (DownloadedAsset) -> Void
    let onPlay: (DownloadedAsset) -> Void
    
    var body: some View {
        NavigationLink(destination: EnhancedShowEpisodesView(group: group, onDelete: onDelete, onPlay: onPlay)) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Group {
                        if let posterURL = group.posterURL {
                            LazyImage(url: posterURL) { state in
                                if let uiImage = state.imageContainer?.image {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Rectangle()
                                        .fill(.tertiary)
                                }
                            }
                        } else {
                            Rectangle()
                                .fill(.tertiary)
                                .overlay(
                                    Image(systemName: "tv")
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                    .frame(width: 56, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.headline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 16) {
                            Label("\(group.assetCount)", systemImage: "play.rectangle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Label(formatFileSize(group.totalFileSize), systemImage: "internaldrive")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
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

struct EnhancedShowEpisodesView: View {
    let group: SimpleDownloadGroup
    let onDelete: (DownloadedAsset) -> Void
    let onPlay: (DownloadedAsset) -> Void
    @State private var showDeleteAlert = false
    @State private var showDeleteAllAlert = false
    @State private var assetToDelete: DownloadedAsset?
    @EnvironmentObject var jsController: JSController
    
    @State private var episodeSortOption: EpisodeSortOption = .episodeOrder

    enum EpisodeSortOption: String, CaseIterable, Identifiable {
        case downloadDate = "Download Date"
        case episodeOrder = "Episode Order"
        
        var id: String { self.rawValue }
        
        var systemImage: String {
            switch self {
            case .downloadDate:
                return "clock.arrow.circlepath"
            case .episodeOrder:
                return "list.number"
            }
        }
    }
    
    private var sortedEpisodes: [DownloadedAsset] {
        switch episodeSortOption {
        case .downloadDate:
            return group.assets.sorted { $0.downloadDate > $1.downloadDate }
        case .episodeOrder:
            return group.assets.sorted { $0.episodeOrderPriority < $1.episodeOrderPriority }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 20) {
                    HStack(alignment: .top, spacing: 20) {
                        Group {
                            if let posterURL = group.posterURL {
                                LazyImage(url: posterURL) { state in
                                    if let uiImage = state.imageContainer?.image {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Rectangle()
                                            .fill(.tertiary)
                                    }
                                }
                            } else {
                                Rectangle()
                                    .fill(.tertiary)
                                    .overlay(
                                        Image(systemName: "tv")
                                            .font(.largeTitle)
                                            .foregroundColor(.secondary)
                                    )
                            }
                        }
                        .frame(width: 120, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(group.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .lineLimit(3)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "play.rectangle.fill")
                                        .foregroundColor(.accentColor)
                                    Text("\(group.assetCount) Episodes")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Image(systemName: "internaldrive.fill")
                                        .foregroundColor(.accentColor)
                                    Text(formatFileSize(group.totalFileSize))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)
                
                // Episodes Section
                VStack(spacing: 16) {
                    // Section Header
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundColor(.accentColor)
                            Text("Episodes".uppercased())
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Menu {
                                ForEach(EpisodeSortOption.allCases) { option in
                                    Button(action: {
                                        episodeSortOption = option
                                    }) {
                                        HStack {
                                            Image(systemName: option.systemImage)
                                            Text(option.rawValue)
                                            if episodeSortOption == option {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: episodeSortOption.systemImage)
                                    Text("Sort")
                                }
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                            }
                            
                            Button(action: {
                                showDeleteAllAlert = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("Delete All")
                                }
                                .font(.subheadline)
                                .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Episodes List
                    if group.assets.isEmpty {
                        Text("No episodes available")
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(40)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(Array(sortedEpisodes.enumerated()), id: \.element.id) { index, asset in
                                EnhancedEpisodeRow(
                                    asset: asset,
                                    showDivider: index < sortedEpisodes.count - 1
                                )
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

struct EnhancedEpisodeRow: View {
    let asset: DownloadedAsset
    let showDivider: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Group {
                    if let backdropURL = asset.metadata?.backdropURL ?? asset.metadata?.posterURL {
                        LazyImage(url: backdropURL) { state in
                            if let uiImage = state.imageContainer?.image {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle()
                                    .fill(.tertiary)
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(.tertiary)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .frame(width: 100, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.episodeDisplayName)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
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
                
                Image(systemName: "play.circle.fill")
                    .foregroundColor(asset.fileExists ? .blue : .gray)
                    .font(.title2)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
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

struct SearchableStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .searchable(text: .constant(""), prompt: "")
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.accentColor.opacity(0.25), location: 0),
                                        .init(color: Color.accentColor.opacity(0), location: 1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
            )
    }
}
