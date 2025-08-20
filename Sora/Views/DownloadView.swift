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
    @State private var showDeleteAllAlert = false
    
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
            .alert(NSLocalizedString("Delete Download", comment: ""), isPresented: $showDeleteAlert) {
                Button(NSLocalizedString("Delete", comment: ""), role: .destructive) {
                    if let asset = assetToDelete {
                        jsController.deleteAsset(asset)
                    }
                }
                Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
            } message: {
                if let asset = assetToDelete {
                    Text(String(format: NSLocalizedString("Are you sure you want to delete '%@'?", comment: ""), asset.episodeDisplayName))
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
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if !jsController.downloadQueue.isEmpty {
                            DownloadSectionView(
                                title: NSLocalizedString("Queue", comment: ""),
                                icon: "clock.fill",
                                downloads: jsController.downloadQueue
                            )
                        }
                        
                        if !jsController.activeDownloads.isEmpty {
                            DownloadSectionView(
                                title: NSLocalizedString("Active Downloads", comment: ""),
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
                ScrollView(showsIndicators: false) {
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
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("No Active Downloads", comment: ""))
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(NSLocalizedString("Actively downloading media can be tracked from here.", comment: ""))
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
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("No Downloads", comment: ""))
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(NSLocalizedString("Your downloaded episodes will appear here", comment: ""))
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
            type: nil,
            novel: false
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
            title: asset.metadata?.showTitle ?? asset.name,
            episodeNumber: asset.metadata?.episode ?? 0,
            episodeTitle: asset.metadata?.episodeTitle ?? "",
            seasonNumber: asset.metadata?.seasonNumber ?? 1,
            onWatchNext: {
                let showTitle = asset.metadata?.showTitle ?? asset.name
                let seasonNumber = asset.metadata?.seasonNumber
                let currentEp = asset.metadata?.episode ?? 0
                let next = jsController.savedAssets
                    .filter { a in
                        let aTitle = a.metadata?.showTitle ?? a.name
                        let sameTitle = (aTitle == showTitle)
                        let sameSeason = (seasonNumber == nil) || (a.metadata?.seasonNumber == seasonNumber)
                        return sameTitle && sameSeason && (a.metadata?.episode ?? 0) > currentEp
                    }
                    .sorted { (a, b) in
                        let ae = a.metadata?.episode ?? 0
                        let be = b.metadata?.episode ?? 0
                        return ae < be
                    }
                    .first
                if let next = next {
                    DispatchQueue.main.async {
                        self.playAsset(next)
                    }
                }
            },
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
                Text(NSLocalizedString("Downloads", comment: ""))
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
                        
                        TextField(NSLocalizedString("Search downloads", comment: ""), text: $searchText)
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
                        title: NSLocalizedString("Active", comment: ""),
                        icon: "arrow.down.circle",
                        isSelected: selectedTab == 0,
                        action: { selectedTab = 0 }
                    )
                    
                    TabButton(
                        title: NSLocalizedString("Downloaded", comment: ""),
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
            Text(NSLocalizedString("Download Summary", comment: "").uppercased())
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
                    title: NSLocalizedString("Shows", comment: ""),
                    value: "\(totalShows)",
                    icon: "tv.fill"
                )

                Divider().frame(height: 32)

                SummaryItem(
                    title: NSLocalizedString("Episodes", comment: ""),
                    value: "\(totalEpisodes)",
                    icon: "play.rectangle.fill"
                )

                Divider().frame(height: 32)

                let formattedSize = formatFileSize(totalSize)
                let components = formattedSize.split(separator: " ")
                let sizeValue = components.first.map(String.init) ?? formattedSize
                let sizeUnit = components.dropFirst().first.map(String.init) ?? ""

                SummaryItem(
                    title: String(format: NSLocalizedString("Size (%@)", comment: ""), sizeUnit),
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
    
    @State private var groupToDelete: SimpleDownloadGroup?
    @State private var showDeleteGroupAlert = false
    @EnvironmentObject var jsController: JSController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                Text(NSLocalizedString("Downloaded Shows", comment: "").uppercased())
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 8) {
                ForEach(groups, id: \ .title) { group in
                    EnhancedDownloadGroupCard(
                        group: group,
                        onDelete: onDelete,
                        onPlay: onPlay
                    )
                    .contextMenu {
                        Button(role: .destructive, action: {
                            groupToDelete = group
                            showDeleteGroupAlert = true
                        }) {
                            Label(NSLocalizedString("Delete All", comment: ""), systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .alert(NSLocalizedString("Delete All Episodes", comment: ""), isPresented: $showDeleteGroupAlert) {
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("Delete All", comment: ""), role: .destructive) {
                if let group = groupToDelete {
                    for asset in group.assets {
                        jsController.deleteAsset(asset)
                    }
                }
                groupToDelete = nil
            }
        } message: {
            if let group = groupToDelete {
                Text(String(format: NSLocalizedString("Are you sure you want to delete all %d episodes in '%@'?", comment: ""), group.assetCount, group.title))
            }
        }
    }
}

@MainActor
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
        HStack(spacing: 14) {
            // Thumbnail
            Group {
                if let imageURL = download.imageURL {
                    LazyImage(url: imageURL) { state in
                        if let uiImage = state.imageContainer?.image {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipped()
                        } else {
                            Rectangle().fill(Color(white: 0.2))
                        }
                    }
                } else {
                    Rectangle().fill(Color(white: 0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Center VStack
            VStack(alignment: .leading, spacing: 4) {
                Text(download.title ?? download.originalURL.lastPathComponent)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack {
                    Text("\(Int(currentProgress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text(statusText)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(white: 0.7))
                            .lineLimit(1)
                    }
                }
                
                ProgressView(value: currentProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(white: 0.7)))
                    .frame(height: 4)
                    .cornerRadius(2)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right VStack (buttons)
            VStack(spacing: 12) {
                Button(action: cancelDownload) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .opacity(0.85)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle().stroke(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color.white.opacity(0.25), location: 0),
                                            .init(color: Color.white.opacity(0), location: 1)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 2
                                )
                            )
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: toggleDownload) {
                    ZStack {
                        Circle()
                            .fill(Color.yellow)
                            .opacity(0.85)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle().stroke(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color.white.opacity(0.25), location: 0),
                                            .init(color: Color.white.opacity(0), location: 1)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 2
                                )
                            )
                        Image(systemName: taskState == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(UIColor.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.gray.opacity(0.2))
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("downloadProgressChanged"))) { _ in
            updateProgress()
        }
    }
    
    private var statusText: String {
        if download.queueStatus == .queued {
            return NSLocalizedString("Queued", comment: "")
        } else if taskState == .running {
            return NSLocalizedString("Downloading", comment: "")
        } else {
            return NSLocalizedString("Paused", comment: "")
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
                            LazyImage(url: posterURL) { @MainActor state in
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
                            HStack(spacing: 4) {
                                Image(systemName: "play.rectangle")
                                Text("\(group.assetCount) \(group.assetCount == 1 ? "Episode" : "Episodes")")
                            }
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    private var fillerBadgeOpacity: Double { colorScheme == .dark ? 0.18 : 0.12 }
    
    @State private var episodeSortOption: EpisodeSortOption = .episodeOrder
    @State private var showFullSynopsis = false

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
        ZStack {
            mainScrollView
                .navigationBarHidden(true)
                .ignoresSafeArea(.container, edges: .top)
            navigationOverlay
        }
        .onAppear {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let navigationController = window.rootViewController?.children.first as? UINavigationController {
                navigationController.interactivePopGestureRecognizer?.isEnabled = true
                navigationController.interactivePopGestureRecognizer?.delegate = nil
            }
            
            NotificationCenter.default.post(name: .hideTabBar, object: nil)
        }
        .onDisappear {
            NotificationCenter.default.post(name: .showTabBar, object: nil)
            UIScrollView.appearance().bounces = true
        }
        .navigationBarBackButtonHidden(true)
    }
    
    @ViewBuilder
    private var navigationOverlay: some View {
        VStack {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                        .circularGradientOutline()
                }
                .padding(.top, 8)
                .padding(.leading, 16)
                Spacer()
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    private var mainScrollView: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .top) {
                heroImageSection
                contentContainer
            }
        }
        .onAppear {
            UIScrollView.appearance().bounces = false
        }
    }
    
    @ViewBuilder
    private var heroImageSection: some View {
        Group {
            if let posterURL = group.posterURL {
                LazyImage(url: posterURL) { @MainActor state in
                    if let uiImage = state.imageContainer?.image {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: UIScreen.main.bounds.width, height: 700)
                            .clipped()
                    } else {
                        placeholderGradient
                    }
                }
            } else {
                placeholderGradient
            }
        }
    }
    
    private var placeholderGradient: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.2)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: UIScreen.main.bounds.width, height: 700)
            .clipped()
    }
    
    @ViewBuilder
    private var contentContainer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 400)
            
            ZStack(alignment: .top) {
                gradientOverlay
                
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    episodesSection
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: (colorScheme == .dark ? Color.black : Color.white).opacity(0.0), location: 0.0),
                .init(color: (colorScheme == .dark ? Color.black : Color.white).opacity(0.5), location: 0.2),
                .init(color: (colorScheme == .dark ? Color.black : Color.white).opacity(0.8), location: 0.5),
                .init(color: (colorScheme == .dark ? Color.black : Color.white), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .shadow(color: (colorScheme == .dark ? Color.black : Color.white).opacity(1), radius: 10, x: 0, y: 10)
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(3)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundColor(.accentColor)
                    Text("\(group.assetCount) \(group.assetCount == 1 ? "Episode" : "Episodes")")
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
            
            HStack(spacing: 12) {
                Button(action: { showDeleteAllAlert = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text(NSLocalizedString("Delete All", comment: ""))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.red.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: Color.red.opacity(0.25), location: 0),
                                                .init(color: Color.red.opacity(0), location: 1)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.accentColor)
                Text(NSLocalizedString("Episodes", comment: "").uppercased())
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            VStack(spacing: 8) {
                ForEach(Array(sortedEpisodes.enumerated()), id: \.element.id) { index, asset in
                    EnhancedEpisodeRow(
                        asset: asset,
                        showDivider: index < sortedEpisodes.count - 1,
                        onPlay: onPlay,
                        onDelete: { asset in
                            assetToDelete = asset
                            showDeleteAlert = true
                        }
                    )
                    .contextMenu {
                        Button(action: { onPlay(asset) }) {
                            Label(NSLocalizedString("Play", comment: ""), systemImage: "play.fill")
                        }
                        .disabled(!asset.fileExists)
                        Button(role: .destructive, action: {
                            assetToDelete = asset
                            showDeleteAlert = true
                        }) {
                            Label(NSLocalizedString("Delete", comment: ""), systemImage: "trash")
                        }
                    }
                    .onTapGesture {
                        onPlay(asset)
                    }
                }
            }
        }
        .alert(NSLocalizedString("Delete Episode", comment: ""), isPresented: $showDeleteAlert) {
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("Delete", comment: ""), role: .destructive) {
                if let asset = assetToDelete {
                    jsController.deleteAsset(asset)
                }
            }
        } message: {
            if let asset = assetToDelete {
                Text(String(format: NSLocalizedString("Are you sure you want to delete '%@'?", comment: ""), asset.episodeDisplayName))
            }
        }
        .alert(NSLocalizedString("Delete All Episodes", comment: ""), isPresented: $showDeleteAllAlert) {
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("Delete All", comment: ""), role: .destructive) {
                deleteAllAssets()
            }
        } message: {
            Text(String(format: NSLocalizedString("Are you sure you want to delete all %d episodes in '%@'?", comment: ""), group.assetCount, group.title))
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

@MainActor
struct EnhancedEpisodeRow: View {
    let asset: DownloadedAsset
    let showDivider: Bool
    let onPlay: (DownloadedAsset) -> Void
    let onDelete: (DownloadedAsset) -> Void
    @State private var swipeOffset: CGFloat = 0
    @State private var isShowingActions: Bool = false
    @State private var dragState = DragState.inactive
    
    struct DragState {
        var translation: CGSize
        var isActive: Bool
        
        static var inactive: DragState {
            DragState(translation: .zero, isActive: false)
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    private var fillerBadgeOpacity: Double { colorScheme == .dark ? 0.18 : 0.12 }
    var body: some View {
        ZStack {
            actionButtonsBackground
            episodeCellContent
        }
    }
    
    private var actionButtonsBackground: some View {
        HStack {
            Spacer()
            Button(action: {
                onDelete(asset)
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    Text("Delete")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .frame(width: 60)
            }
            .frame(height: 76)
        }
        .zIndex(0)
    }
    
    private var episodeCellContent: some View {
        HStack {
            // Thumbnail
            Group {
                if let backdropURL = asset.metadata?.backdropURL ?? asset.metadata?.posterURL {
                    LazyImage(url: backdropURL) { @MainActor state in
                        if let uiImage = state.imageContainer?.image {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(.tertiary)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                )
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
            .frame(width: 100, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading) {
                HStack(spacing: 8) {
                    Text("Episode \(asset.metadata?.episode ?? 0)")
                        .font(.system(size: 15))
                    if asset.metadata?.isFiller == true {
                        Text("Filler")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(fillerBadgeOpacity), in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.red.opacity(0.24), lineWidth: 0.6)
                            )
                            .foregroundColor(.red)
                    }
                }
                if let title = asset.metadata?.title {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            CircularProgressBar(progress: 0.0)
                .frame(width: 40, height: 40)
                .padding(.trailing, 4)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(cellBackground)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .offset(x: swipeOffset + dragState.translation.width)
        .zIndex(1)
        .scaleEffect(dragState.isActive ? 0.98 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: swipeOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dragState.isActive)
        .simultaneousGesture(
            DragGesture(coordinateSpace: .local)
                .onChanged { value in
                    handleDragChanged(value)
                }
                .onEnded { value in
                    handleDragEnded(value)
                }
        )
        .onTapGesture { handleTap() }
    }
    
    private var cellBackground: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color(UIColor.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.gray.opacity(0.2))
            )
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
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        let translation = value.translation
        let velocity = value.velocity
        
        let isHorizontalGesture = abs(translation.width) > abs(translation.height)
        let hasSignificantHorizontalMovement = abs(translation.width) > 10
        
        if isHorizontalGesture && hasSignificantHorizontalMovement {
            dragState = .inactive
            
            let proposedOffset = swipeOffset + translation.width
            let maxSwipe: CGFloat = 60 // Only one button
            
            if translation.width < 0 {
                let newOffset = max(proposedOffset, -maxSwipe)
                if proposedOffset < -maxSwipe {
                    let resistance = abs(proposedOffset + maxSwipe) * 0.15
                    swipeOffset = -maxSwipe - resistance
                } else {
                    swipeOffset = newOffset
                }
            } else if isShowingActions {
                swipeOffset = min(max(proposedOffset, -maxSwipe), maxSwipe * 0.2)
            }
        } else if !hasSignificantHorizontalMovement {
            dragState = .inactive
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let translation = value.translation
        let velocity = value.velocity
        
        dragState = .inactive
        
        let isHorizontalGesture = abs(translation.width) > abs(translation.height)
        let hasSignificantHorizontalMovement = abs(translation.width) > 10
        
        if isHorizontalGesture && hasSignificantHorizontalMovement {
            let maxSwipe: CGFloat = 60
            let threshold = maxSwipe * 0.3
            let velocityThreshold: CGFloat = 500
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if translation.width < -threshold || velocity.width < -velocityThreshold {
                    swipeOffset = -maxSwipe
                    isShowingActions = true
                } else if translation.width > threshold || velocity.width > velocityThreshold {
                    swipeOffset = 0
                    isShowingActions = false
                } else {
                    swipeOffset = isShowingActions ? -maxSwipe : 0
                }
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                swipeOffset = isShowingActions ? -60 : 0
            }
        }
    }
    
    private func handleTap() {
        if isShowingActions {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                swipeOffset = 0
                isShowingActions = false
            }
        } else {
            onPlay(asset)
        }
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