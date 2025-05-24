//
//  EpisodeCell.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import Kingfisher
import AVFoundation

struct EpisodeLink: Identifiable {
    let id = UUID()
    let number: Int
    let href: String
}

struct EpisodeCell: View {
    let episodeIndex: Int
    let episode: String
    let episodeID: Int
    let progress: Double
    let itemID: Int
    var totalEpisodes: Int?
    var defaultBannerImage: String
    var module: ScrapingModule
    var parentTitle: String
    var showPosterURL: String?
    
    var isMultiSelectMode: Bool = false
    var isSelected: Bool = false
    var onSelectionChanged: ((Bool) -> Void)?
    
    var onTap: (String) -> Void
    var onMarkAllPrevious: () -> Void
    
    @State private var episodeTitle: String = ""
    @State private var episodeImageUrl: String = ""
    @State private var isLoading: Bool = true
    @State private var currentProgress: Double = 0.0
    @State private var showDownloadConfirmation = false
    @State private var isDownloading: Bool = false
    @State private var isPlaying = false
    @State private var loadedFromCache: Bool = false
    @State private var downloadStatus: EpisodeDownloadStatus = .notDownloaded
    @State private var downloadRefreshTrigger: Bool = false
    @State private var lastUpdateTime: Date = Date()
    @State private var activeDownloadTask: AVAssetDownloadTask? = nil
    @State private var lastStatusCheck: Date = Date()
    @State private var lastLoggedStatus: EpisodeDownloadStatus?
    @State private var downloadAnimationScale: CGFloat = 1.0
    
    @State private var retryAttempts: Int = 0
    private let maxRetryAttempts: Int = 3
    private let initialBackoffDelay: TimeInterval = 1.0
    
    @ObservedObject private var jsController = JSController.shared
    @EnvironmentObject var moduleManager: ModuleManager
    
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedAppearance") private var selectedAppearance: Appearance = .system
    
    private var downloadStatusString: String {
        switch downloadStatus {
        case .notDownloaded:
            return "notDownloaded"
        case .downloading(let download):
            return "downloading_\(download.id)"
        case .downloaded(let asset):
            return "downloaded_\(asset.id)"
        }
    }
    
    init(episodeIndex: Int, episode: String, episodeID: Int, progress: Double,
         itemID: Int, totalEpisodes: Int? = nil, defaultBannerImage: String = "",
         module: ScrapingModule, parentTitle: String, showPosterURL: String? = nil,
         isMultiSelectMode: Bool = false, isSelected: Bool = false,
         onSelectionChanged: ((Bool) -> Void)? = nil,
         onTap: @escaping (String) -> Void, onMarkAllPrevious: @escaping () -> Void) {
        self.episodeIndex = episodeIndex
        self.episode = episode
        self.episodeID = episodeID
        self.progress = progress
        self.itemID = itemID
        self.totalEpisodes = totalEpisodes
        
        let isLightMode = (UserDefaults.standard.string(forKey: "selectedAppearance") == "light") ||
        ((UserDefaults.standard.string(forKey: "selectedAppearance") == "system") &&
         UITraitCollection.current.userInterfaceStyle == .light)
        let defaultLightBanner = "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner1.png"
        let defaultDarkBanner = "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner2.png"
        
        self.defaultBannerImage = defaultBannerImage.isEmpty ?
        (isLightMode ? defaultLightBanner : defaultDarkBanner) : defaultBannerImage
        
        self.module = module
        self.parentTitle = parentTitle
        self.showPosterURL = showPosterURL
        self.isMultiSelectMode = isMultiSelectMode
        self.isSelected = isSelected
        self.onSelectionChanged = onSelectionChanged
        self.onTap = onTap
        self.onMarkAllPrevious = onMarkAllPrevious
    }
    
    var body: some View {
        HStack {
            episodeThumbnail
            episodeInfo
            Spacer()
            CircularProgressBar(progress: currentProgress)
                .frame(width: 40, height: 40)
                .padding(.trailing, 8)
        }
        .contentShape(Rectangle())
        .background(isMultiSelectMode && isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contextMenu {
            contextMenuContent
        }
        .onAppear {
            updateProgress()
            updateDownloadStatus()
            
            if let type = module.metadata.type?.lowercased(), type == "anime" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    fetchAnimeEpisodeDetails()
                }
            }
            
            if let totalEpisodes = totalEpisodes, episodeID + 1 < totalEpisodes {
                let nextEpisodeStart = episodeID + 1
                let count = min(5, totalEpisodes - episodeID - 1)
            }
        }
        .onDisappear {
            activeDownloadTask = nil
        }
        .onChange(of: progress) { _ in
            updateProgress()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("downloadProgressChanged"))) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                updateDownloadStatus()
                updateProgress()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("downloadStatusChanged"))) { _ in
            updateDownloadStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("downloadCompleted"))) { _ in
            updateDownloadStatus()
        }
        .onTapGesture {
            if isMultiSelectMode {
                onSelectionChanged?(!isSelected)
            } else {
                let imageUrl = episodeImageUrl.isEmpty ? defaultBannerImage : episodeImageUrl
                onTap(imageUrl)
            }
        }
        .alert("Download Episode", isPresented: $showDownloadConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Download") {
                downloadEpisode()
            }
        } message: {
            Text("Do you want to download Episode \(episodeID + 1)\(episodeTitle.isEmpty ? "" : ": \(episodeTitle)")?")
        }
    }
    
    private var episodeThumbnail: some View {
        ZStack {
            if let url = URL(string: episodeImageUrl.isEmpty ? defaultBannerImage : episodeImageUrl) {
                KFImage.optimizedEpisodeThumbnail(url: url)
                    .onFailure { error in
                        Logger.shared.log("Failed to load episode image: \(error)", type: "Error")
                    }
                    .cacheMemoryOnly(!KingfisherCacheManager.shared.isCachingEnabled)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 100, height: 56)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 56)
                    .cornerRadius(8)
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }
    
    private var episodeInfo: some View {
        VStack(alignment: .leading) {
            Text("Episode \(episodeID + 1)")
                .font(.system(size: 15))
            if !episodeTitle.isEmpty {
                Text(episodeTitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var downloadStatusView: some View {
        Group {
            switch downloadStatus {
            case .notDownloaded:
                downloadButton
            case .downloading(let activeDownload):
                if activeDownload.queueStatus == .queued {
                    queuedIndicator
                } else {
                    downloadProgressView
                }
            case .downloaded:
                downloadedIndicator
            }
        }
    }
    
    private var downloadButton: some View {
        Button(action: {
            showDownloadConfirmation = true
        }) {
            Image(systemName: "arrow.down.circle")
                .foregroundColor(.blue)
                .font(.title3)
        }
        .padding(.horizontal, 8)
    }
    
    private var downloadProgressView: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.blue)
                .font(.title3)
                .scaleEffect(downloadAnimationScale)
                .onAppear {
                    withAnimation(
                        Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                    ) {
                        downloadAnimationScale = 1.2
                    }
                }
                .onDisappear {
                    downloadAnimationScale = 1.0
                }
        }
        .padding(.horizontal, 8)
    }
    
    private var downloadedIndicator: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
            .font(.title3)
            .padding(.horizontal, 8)
            .scaleEffect(1.1)
            .animation(.default, value: downloadStatusString)
    }
    
    private var queuedIndicator: some View {
        HStack(spacing: 4) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.8)
                .accentColor(.orange)
            
            Text("Queued")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
    }
    
    private var contextMenuContent: some View {
        Group {
            if progress <= 0.9 {
                Button(action: markAsWatched) {
                    Label("Mark as Watched", systemImage: "checkmark.circle")
                }
            }
            
            if progress != 0 {
                Button(action: resetProgress) {
                    Label("Reset Progress", systemImage: "arrow.counterclockwise")
                }
            }
            
            if episodeIndex > 0 {
                Button(action: onMarkAllPrevious) {
                    Label("Mark All Previous Watched", systemImage: "checkmark.circle.fill")
                }
            }
            
            Button(action: downloadEpisode) {
                Label("Download Episode", systemImage: "arrow.down.circle")
            }
        }
    }
    
    private func updateDownloadStatus() {
        let newStatus = jsController.isEpisodeDownloadedOrInProgress(
            showTitle: parentTitle,
            episodeNumber: episodeID + 1
        )
        
        if downloadStatus != newStatus {
            downloadStatus = newStatus
        }
    }
    
    private func downloadEpisode() {
        updateDownloadStatus()
        
        if case .notDownloaded = downloadStatus, !isDownloading {
            isDownloading = true
            let downloadID = UUID()
            
            DropManager.shared.downloadStarted(episodeNumber: episodeID + 1)
            
            Task {
                do {
                    let jsContent = try moduleManager.getModuleContent(module)
                    jsController.loadScript(jsContent)
                    tryNextDownloadMethod(methodIndex: 0, downloadID: downloadID, softsub: module.metadata.softsub == true)
                } catch {
                    DropManager.shared.error("Failed to start download: \(error.localizedDescription)")
                    isDownloading = false
                }
            }
        } else {
            if case .downloaded = downloadStatus {
                DropManager.shared.info("Episode \(episodeID + 1) is already downloaded")
            } else if case .downloading = downloadStatus {
                DropManager.shared.info("Episode \(episodeID + 1) is already being downloaded")
            }
        }
    }
    
    private func tryNextDownloadMethod(methodIndex: Int, downloadID: UUID, softsub: Bool) {
        if !isDownloading {
            return
        }
        
        print("[Download] Trying download method #\(methodIndex+1) for Episode \(episodeID + 1)")
        
        switch methodIndex {
        case 0:
            if module.metadata.asyncJS == true {
                jsController.fetchStreamUrlJS(episodeUrl: episode, softsub: softsub, module: module) { result in
                    self.handleSequentialDownloadResult(result, downloadID: downloadID, methodIndex: methodIndex, softsub: softsub)
                }
            } else {
                tryNextDownloadMethod(methodIndex: methodIndex + 1, downloadID: downloadID, softsub: softsub)
            }
            
        case 1:
            if module.metadata.streamAsyncJS == true {
                jsController.fetchStreamUrlJSSecond(episodeUrl: episode, softsub: softsub, module: module) { result in
                    self.handleSequentialDownloadResult(result, downloadID: downloadID, methodIndex: methodIndex, softsub: softsub)
                }
            } else {
                tryNextDownloadMethod(methodIndex: methodIndex + 1, downloadID: downloadID, softsub: softsub)
            }
            
        case 2:
            jsController.fetchStreamUrl(episodeUrl: episode, softsub: softsub, module: module) { result in
                self.handleSequentialDownloadResult(result, downloadID: downloadID, methodIndex: methodIndex, softsub: softsub)
            }
            
        default:
            DropManager.shared.error("Failed to find a valid stream for download after trying all methods")
            isDownloading = false
        }
    }
    
    private func handleSequentialDownloadResult(_ result: (streams: [String]?, subtitles: [String]?, sources: [[String:Any]]?), downloadID: UUID, methodIndex: Int, softsub: Bool) {
        if !isDownloading {
            return
        }
        
        if let streams = result.streams, !streams.isEmpty, let url = URL(string: streams[0]) {
            if streams[0] == "[object Promise]" {
                print("[Download] Method #\(methodIndex+1) returned a Promise object, trying next method")
                tryNextDownloadMethod(methodIndex: methodIndex + 1, downloadID: downloadID, softsub: softsub)
                return
            }
            
            print("[Download] Method #\(methodIndex+1) returned valid stream URL: \(streams[0])")
            
            let subtitleURL = result.subtitles?.first.flatMap { URL(string: $0) }
            if let subtitleURL = subtitleURL {
                print("[Download] Found subtitle URL: \(subtitleURL.absoluteString)")
            }
            
            startActualDownload(url: url, streamUrl: streams[0], downloadID: downloadID, subtitleURL: subtitleURL)
        } else if let sources = result.sources, !sources.isEmpty,
                    let streamUrl = sources[0]["streamUrl"] as? String,
                    let url = URL(string: streamUrl) {
            
            print("[Download] Method #\(methodIndex+1) returned valid stream URL with headers: \(streamUrl)")
            
            let subtitleURLString = sources[0]["subtitle"] as? String
            let subtitleURL = subtitleURLString.flatMap { URL(string: $0) }
            if let subtitleURL = subtitleURL {
                print("[Download] Found subtitle URL: \(subtitleURL.absoluteString)")
            }
            
            startActualDownload(url: url, streamUrl: streamUrl, downloadID: downloadID, subtitleURL: subtitleURL)
        } else {
            print("[Download] Method #\(methodIndex+1) did not return valid streams, trying next method")
            tryNextDownloadMethod(methodIndex: methodIndex + 1, downloadID: downloadID, softsub: softsub)
        }
    }
    
    private func startActualDownload(url: URL, streamUrl: String, downloadID: UUID, subtitleURL: URL? = nil) {
        var headers: [String: String] = [:]
        
        if !module.metadata.baseUrl.isEmpty && !module.metadata.baseUrl.contains("undefined") {
            print("Using module baseUrl: \(module.metadata.baseUrl)")
            
            headers = [
                "Origin": module.metadata.baseUrl,
                "Referer": module.metadata.baseUrl,
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
                "Accept": "*/*",
                "Accept-Language": "en-US,en;q=0.9",
                "Sec-Fetch-Dest": "empty",
                "Sec-Fetch-Mode": "cors",
                "Sec-Fetch-Site": "same-origin"
            ]
        } else {
            if let scheme = url.scheme, let host = url.host {
                let baseUrl = scheme + "://" + host
                
                headers = [
                    "Origin": baseUrl,
                    "Referer": baseUrl,
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
                    "Accept": "*/*",
                    "Accept-Language": "en-US,en;q=0.9",
                    "Sec-Fetch-Dest": "empty",
                    "Sec-Fetch-Mode": "cors",
                    "Sec-Fetch-Site": "same-origin"
                ]
            } else {
                DropManager.shared.error("Invalid stream URL - missing scheme or host")
                isDownloading = false
                return
            }
        }
        
        print("Download headers: \(headers)")
        
        let episodeThumbnailURL = URL(string: episodeImageUrl.isEmpty ? defaultBannerImage : episodeImageUrl)
        let showPosterImageURL = URL(string: showPosterURL ?? defaultBannerImage)
        
        let episodeName = episodeTitle.isEmpty ? "Episode \(episodeID + 1)" : episodeTitle
        let fullEpisodeTitle = "Episode \(episodeID + 1): \(episodeName)"
        
        let animeTitle = parentTitle.isEmpty ? "Unknown Anime" : parentTitle
        
        jsController.downloadWithStreamTypeSupport(
            url: url,
            headers: headers,
            title: fullEpisodeTitle,
            imageURL: episodeThumbnailURL,
            module: module,
            isEpisode: true,
            showTitle: animeTitle,
            season: 1,
            episode: episodeID + 1,
            subtitleURL: subtitleURL,
            showPosterURL: showPosterImageURL,
            completionHandler: { success, message in
                if success {
                    Logger.shared.log("Started download for Episode \(self.episodeID + 1): \(self.episode)", type: "Download")
                    AnalyticsManager.shared.sendEvent(
                        event: "download",
                        additionalData: ["episode": self.episodeID + 1, "url": streamUrl]
                    )
                } else {
                    DropManager.shared.error(message)
                }
                self.isDownloading = false
            }
        )
    }
    
    private func markAsWatched() {
        let userDefaults = UserDefaults.standard
        let totalTime = 1000.0
        let watchedTime = totalTime
        userDefaults.set(watchedTime, forKey: "lastPlayedTime_\(episode)")
        userDefaults.set(totalTime, forKey: "totalTime_\(episode)")
        DispatchQueue.main.async {
            self.updateProgress()
        }
    }
    
    private func resetProgress() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(0.0, forKey: "lastPlayedTime_\(episode)")
        userDefaults.set(0.0, forKey: "totalTime_\(episode)")
        DispatchQueue.main.async {
            self.updateProgress()
        }
    }
    
    private func updateProgress() {
        let userDefaults = UserDefaults.standard
        let lastPlayedTime = userDefaults.double(forKey: "lastPlayedTime_\(episode)")
        let totalTime = userDefaults.double(forKey: "totalTime_\(episode)")
        currentProgress = totalTime > 0 ? min(lastPlayedTime / totalTime, 1.0) : 0
    }
    
    private func fetchEpisodeDetails() {
        if MetadataCacheManager.shared.isCachingEnabled &&
            (UserDefaults.standard.object(forKey: "fetchEpisodeMetadata") == nil ||
             UserDefaults.standard.bool(forKey: "fetchEpisodeMetadata")) {
            
            let cacheKey = "anilist_\(itemID)_episode_\(episodeID + 1)"
            
            if let cachedData = MetadataCacheManager.shared.getMetadata(forKey: cacheKey),
               let metadata = EpisodeMetadata.fromData(cachedData) {
                
                DispatchQueue.main.async {
                    self.episodeTitle = metadata.title["en"] ?? ""
                    self.episodeImageUrl = metadata.imageUrl
                    self.isLoading = false
                    self.loadedFromCache = true
                }
                return
            }
        }
        
        fetchAnimeEpisodeDetails()
    }
    
    private func fetchAnimeEpisodeDetails() {
        guard let url = URL(string: "https://api.ani.zip/mappings?anilist_id=\(itemID)") else {
            isLoading = false
            Logger.shared.log("Invalid URL for itemID: \(itemID)", type: "Error")
            return
        }
        
        if retryAttempts > 0 {
            Logger.shared.log("Retrying episode details fetch (attempt \(retryAttempts)/\(maxRetryAttempts))", type: "Debug")
        }
        
        URLSession.custom.dataTask(with: url) { data, response, error in
            if let error = error {
                Logger.shared.log("Failed to fetch anime episode details: \(error)", type: "Error")
                self.handleFetchFailure(error: error)
                return
            }
            
            guard let data = data else {
                self.handleFetchFailure(error: NSError(domain: "com.sora.episode", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any] else {
                    self.handleFetchFailure(error: NSError(domain: "com.sora.episode", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"]))
                    return
                }
                
                guard let episodes = json["episodes"] as? [String: Any] else {
                    Logger.shared.log("Missing 'episodes' object in response", type: "Error")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.retryAttempts = 0
                    }
                    return
                }
                
                let episodeKey = "\(episodeID + 1)"
                guard let episodeDetails = episodes[episodeKey] as? [String: Any] else {
                    Logger.shared.log("Episode \(episodeKey) not found in response", type: "Error")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.retryAttempts = 0
                    }
                    return
                }
                
                var title: [String: String] = [:]
                var image: String = ""
                var missingFields: [String] = []
                
                if let titleData = episodeDetails["title"] as? [String: String], !titleData.isEmpty {
                    title = titleData
                    
                    if title.values.allSatisfy({ $0.isEmpty }) {
                        missingFields.append("title (all values empty)")
                    }
                } else {
                    missingFields.append("title")
                }
                
                if let imageUrl = episodeDetails["image"] as? String, !imageUrl.isEmpty {
                    image = imageUrl
                } else {
                    missingFields.append("image")
                }
                
                if !missingFields.isEmpty {
                    Logger.shared.log("Episode \(episodeKey) missing fields: \(missingFields.joined(separator: ", "))", type: "Warning")
                }
                
                if MetadataCacheManager.shared.isCachingEnabled && (!title.isEmpty || !image.isEmpty) {
                    let metadata = EpisodeMetadata(
                        title: title,
                        imageUrl: image,
                        anilistId: self.itemID,
                        episodeNumber: self.episodeID + 1
                    )
                    
                    if let metadataData = metadata.toData() {
                        MetadataCacheManager.shared.storeMetadata(
                            metadataData,
                            forKey: metadata.cacheKey
                        )
                    }
                }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.retryAttempts = 0
                    
                    if UserDefaults.standard.object(forKey: "fetchEpisodeMetadata") == nil
                        || UserDefaults.standard.bool(forKey: "fetchEpisodeMetadata") {
                        self.episodeTitle = title["en"] ?? title.values.first ?? ""
                        
                        if !image.isEmpty {
                            self.episodeImageUrl = image
                        }
                    }
                }
            } catch {
                Logger.shared.log("JSON parsing error: \(error.localizedDescription)", type: "Error")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.retryAttempts = 0
                }
            }
        }.resume()
    }
    
    private func handleFetchFailure(error: Error) {
        Logger.shared.log("Episode details fetch error: \(error.localizedDescription)", type: "Error")
        
        DispatchQueue.main.async {
            if self.retryAttempts < self.maxRetryAttempts {
                self.retryAttempts += 1
                
                let backoffDelay = self.initialBackoffDelay * pow(2.0, Double(self.retryAttempts - 1))
                
                Logger.shared.log("Will retry episode details fetch in \(backoffDelay) seconds", type: "Debug")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + backoffDelay) {
                    self.fetchAnimeEpisodeDetails()
                }
            } else {
                Logger.shared.log("Failed to fetch episode details after \(self.maxRetryAttempts) attempts", type: "Error")
                self.isLoading = false
                self.retryAttempts = 0
            }
        }
    }
}
