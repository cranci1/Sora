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
    @State private var downloadProgress: Double = 0.0
    @State private var downloadRefreshTrigger: Bool = false
    @State private var lastUpdateTime: Date = Date()
    @State private var activeDownloadTask: AVAssetDownloadTask? = nil
    @State private var lastStatusCheck: Date = Date()
    @State private var lastLoggedStatus: EpisodeDownloadStatus?
    
    @ObservedObject private var jsController = JSController.shared
    @EnvironmentObject var moduleManager: ModuleManager
    
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedAppearance") private var selectedAppearance: Appearance = .system
    
    init(episodeIndex: Int, episode: String, episodeID: Int, progress: Double,
         itemID: Int, totalEpisodes: Int? = nil, defaultBannerImage: String = "",
         module: ScrapingModule, parentTitle: String, 
         onTap: @escaping (String) -> Void, onMarkAllPrevious: @escaping () -> Void) {
        self.episodeIndex = episodeIndex
        self.episode = episode
        self.episodeID = episodeID
        self.progress = progress
        self.itemID = itemID
        self.totalEpisodes = totalEpisodes
        
        // Initialize banner image based on appearance
        let isLightMode = (UserDefaults.standard.string(forKey: "selectedAppearance") == "light") || 
                         ((UserDefaults.standard.string(forKey: "selectedAppearance") == "system") && 
                          UITraitCollection.current.userInterfaceStyle == .light)
        let defaultLightBanner = "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner1.png"
        let defaultDarkBanner = "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner2.png"
        
        self.defaultBannerImage = defaultBannerImage.isEmpty ? 
            (isLightMode ? defaultLightBanner : defaultDarkBanner) : defaultBannerImage
        
        self.module = module
        self.parentTitle = parentTitle
        self.onTap = onTap
        self.onMarkAllPrevious = onMarkAllPrevious
    }
    
    var body: some View {
        HStack {
            episodeThumbnail
            episodeInfo
            Spacer()
            downloadStatusView
            CircularProgressBar(progress: currentProgress)
                .frame(width: 40, height: 40)
        }
        .contentShape(Rectangle())
        .contextMenu {
            contextMenuContent
        }
        .onAppear {
            updateProgress()
            fetchEpisodeDetails()
            updateDownloadStatus()
            observeDownloadProgress()
        }
        .onDisappear {
            activeDownloadTask = nil
        }
        .onChange(of: progress) { _ in
            updateProgress()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("downloadStatusChanged"))) { _ in
            updateDownloadStatus()
            updateProgress()
        }
        .onTapGesture {
            let imageUrl = episodeImageUrl.isEmpty ? defaultBannerImage : episodeImageUrl
            onTap(imageUrl)
        }
        .alert("Download Episode", isPresented: $showDownloadConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Download") {
                downloadEpisode()
            }
        } message: {
            Text("Do you want to download Episode \(episodeID + 1)\(episodeTitle.isEmpty ? "" : ": \(episodeTitle)")?")
        }
        .id("\(episode)_\(downloadRefreshTrigger)_\(Int(downloadProgress * 100))")
    }
    
    // MARK: - View Components
    
    private var episodeThumbnail: some View {
        ZStack {
            KFImage(URL(string: episodeImageUrl.isEmpty ? defaultBannerImage : episodeImageUrl))
                .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 100, height: 56)))
                .memoryCacheExpiration(.seconds(300))
                .cacheOriginalImage()
                .cacheMemoryOnly(!KingfisherCacheManager.shared.isCachingEnabled)
                .fade(duration: 0.25)
                .onSuccess { _ in
                    if !loadedFromCache {
                        Logger.shared.log("Loaded episode \(episodeID + 1) image from network", type: "Debug")
                    }
                }
                .onFailure { error in
                    Logger.shared.log("Failed to load episode image: \(error)", type: "Error")
                }
                .resizable()
                .aspectRatio(16/9, contentMode: .fill)
                .frame(width: 100, height: 56)
                .cornerRadius(8)
            
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
            case .downloading(_):
                downloadProgressView
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
            let clampedProgress = min(max(downloadProgress, 0.0), 1.0)
            Text("\(Int(clampedProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressView(value: clampedProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 40)
        }
        .padding(.horizontal, 8)
        .id("progress_\(Int(downloadProgress * 100))_\(lastUpdateTime.timeIntervalSince1970)")
    }
    
    private var downloadedIndicator: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
            .font(.title3)
            .padding(.horizontal, 8)
            .transition(.opacity)
            .animation(.easeInOut, value: downloadProgress)
    }
    
    private var contextMenuContent: some View {
        Group {
            if case .notDownloaded = downloadStatus {
                Button(action: {
                    showDownloadConfirmation = true
                }) {
                    Label("Download Episode", systemImage: "arrow.down.circle")
                }
            }
            
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
        }
    }
    
    private func updateDownloadStatus() {
        // Debounce status checks - only check every 0.5 seconds
        let now = Date()
        guard now.timeIntervalSince(lastStatusCheck) >= 0.5 else {
            return
        }
        lastStatusCheck = now
        
        let previousStatus = downloadStatus
        downloadStatus = jsController.isEpisodeDownloadedOrInProgress(
            showTitle: parentTitle,
            episodeNumber: episodeID + 1
        )
        
        // Only log if the status has actually changed
        if lastLoggedStatus != downloadStatus {
            lastLoggedStatus = downloadStatus
            
            // Update download progress when status changes
            if case .downloading(let activeDownload) = downloadStatus {
                // Store the active download task for direct progress observation
                activeDownloadTask = activeDownload.task
                
                // Update our local download progress state
                let newProgress = activeDownload.progress
                let clampedProgress = min(max(newProgress, 0.0), 1.0)
                
                // Check if the progress has actually changed to avoid unnecessary UI updates
                if case .downloading(let prevDownload) = previousStatus, prevDownload.progress == newProgress {
                    // No progress change, do nothing
                } else {
                    // Progress has changed, update state and force refresh
                    downloadProgress = clampedProgress
                    lastUpdateTime = Date() // Update timestamp
                    downloadRefreshTrigger.toggle()
                    
                    // If progress is complete, force state to .downloaded
                    if clampedProgress >= 1.0 {
                        // Try to get the downloaded asset
                        if let asset = jsController.savedAssets.first(where: { asset in
                            asset.type == .episode &&
                            asset.metadata?.showTitle?.caseInsensitiveCompare(parentTitle) == .orderedSame &&
                            asset.metadata?.episode == episodeID + 1
                        }) {
                            // Update on main thread to ensure UI updates
                            DispatchQueue.main.async {
                                self.downloadStatus = .downloaded(asset)
                                self.downloadProgress = 1.0
                                self.downloadRefreshTrigger.toggle()
                                
                                // Force a UI update
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("downloadStatusChanged"),
                                    object: nil
                                )
                            }
                        }
                    }
                    // Log for debugging
                    print("Episode \(episodeID + 1) progress updated: \(Int(clampedProgress * 100))%")
                }
            } else if case .downloaded(let asset) = downloadStatus {
                // If we have a downloaded asset, ensure we show the checkmark
                DispatchQueue.main.async {
                    self.downloadProgress = 1.0
                    self.downloadRefreshTrigger.toggle()
                    
                    // Log the download state for debugging
                    print("Episode \(self.episodeID + 1) is downloaded")
                    if let subtitleURL = asset.subtitleURL {
                        print("Has subtitle URL: \(subtitleURL)")
                    } else {
                        print("No subtitle URL - video only")
                    }
                }
            } else {
                // Reset download progress if no longer downloading
                if downloadProgress != 0.0 {
                    downloadProgress = 0.0
                    lastUpdateTime = Date() // Update timestamp
                    downloadRefreshTrigger.toggle()
                }
                
                // Clear the active download task
                activeDownloadTask = nil
                
                // Also toggle refresh trigger when status changes to not downloading
                if case .downloading = previousStatus {
                    downloadRefreshTrigger.toggle()
                }
            }
        }
    }
    
    private func observeDownloadProgress() {
        // We'll rely on the notification system instead of a timer
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("downloadProgressUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let episodeNumber = userInfo["episodeNumber"] as? Int,
                  let progress = userInfo["progress"] as? Double,
                  episodeNumber == self.episodeID + 1 else {
                return
            }
            
            // Only update if the progress has changed significantly
            if abs(progress - self.downloadProgress) > 0.001 {
                self.downloadProgress = progress
                self.lastUpdateTime = Date()
                self.downloadRefreshTrigger.toggle()
                
                // If progress is 100%, ensure we show the downloaded state
                if progress >= 1.0 {
                    // Force an immediate status update
                    DispatchQueue.main.async {
                        self.updateDownloadStatus()
                    }
                }
            }
        }
    }
    
    private func downloadEpisode() {
        // Check the current download status
        updateDownloadStatus()
        
        // Don't proceed if the episode is already downloaded or being downloaded
        if case .notDownloaded = downloadStatus, !isDownloading {
            isDownloading = true
            let downloadID = UUID()
            
            DropManager.shared.showDrop(
                title: "Preparing Download",
                subtitle: "Episode \(episodeID + 1)",
                duration: 0.5,
                icon: UIImage(systemName: "arrow.down.circle")
            )
            
            Task {
                do {
                    let jsContent = try moduleManager.getModuleContent(module)
                    jsController.loadScript(jsContent)
                    
                    // Try download methods sequentially instead of in parallel
                    tryNextDownloadMethod(methodIndex: 0, downloadID: downloadID, softsub: module.metadata.softsub == true)
                } catch {
                    DropManager.shared.error("Failed to start download: \(error.localizedDescription)")
                    isDownloading = false
                }
            }
        } else {
            // Handle case where download is already in progress or completed
            if case .downloaded = downloadStatus {
                DropManager.shared.info("Episode \(episodeID + 1) is already downloaded")
            } else if case .downloading = downloadStatus {
                DropManager.shared.info("Episode \(episodeID + 1) is already being downloaded")
            }
        }
    }
    
    // Try each download method sequentially
    private func tryNextDownloadMethod(methodIndex: Int, downloadID: UUID, softsub: Bool) {
        if !isDownloading {
            return
        }
        
        print("[Download] Trying download method #\(methodIndex+1) for Episode \(episodeID + 1)")
        
        switch methodIndex {
        case 0:
            // First try fetchStreamUrlJS if asyncJS is true
            if module.metadata.asyncJS == true {
                jsController.fetchStreamUrlJS(episodeUrl: episode, softsub: softsub, module: module) { result in
                    self.handleSequentialDownloadResult(result, downloadID: downloadID, methodIndex: methodIndex, softsub: softsub)
                }
            } else {
                // Skip to next method if not applicable
                tryNextDownloadMethod(methodIndex: methodIndex + 1, downloadID: downloadID, softsub: softsub)
            }
            
        case 1:
            // Then try fetchStreamUrlJSSecond if streamAsyncJS is true
            if module.metadata.streamAsyncJS == true {
                jsController.fetchStreamUrlJSSecond(episodeUrl: episode, softsub: softsub, module: module) { result in
                    self.handleSequentialDownloadResult(result, downloadID: downloadID, methodIndex: methodIndex, softsub: softsub)
                }
            } else {
                // Skip to next method if not applicable
                tryNextDownloadMethod(methodIndex: methodIndex + 1, downloadID: downloadID, softsub: softsub)
            }
            
        case 2:
            // Finally try fetchStreamUrl (most reliable method)
            jsController.fetchStreamUrl(episodeUrl: episode, softsub: softsub, module: module) { result in
                self.handleSequentialDownloadResult(result, downloadID: downloadID, methodIndex: methodIndex, softsub: softsub)
            }
            
        default:
            // We've tried all methods and none worked
            DropManager.shared.error("Failed to find a valid stream for download after trying all methods")
            isDownloading = false
        }
    }
    
    // Handle result from sequential download attempts
    private func handleSequentialDownloadResult(_ result: (streams: [String]?, subtitles: [String]?), downloadID: UUID, methodIndex: Int, softsub: Bool) {
        // Skip if we're no longer downloading
        if !isDownloading {
            return
        }
        
        // Check if we have valid streams
        if let streams = result.streams, !streams.isEmpty, let url = URL(string: streams[0]) {
            // Check if it's a Promise object
            if streams[0] == "[object Promise]" {
                print("[Download] Method #\(methodIndex+1) returned a Promise object, trying next method")
                tryNextDownloadMethod(methodIndex: methodIndex + 1, downloadID: downloadID, softsub: softsub)
                return
            }
            
            // We found a valid stream URL, proceed with download
            print("[Download] Method #\(methodIndex+1) returned valid stream URL: \(streams[0])")
            
            // Get subtitle URL if available
            let subtitleURL = result.subtitles?.first.flatMap { URL(string: $0) }
            if let subtitleURL = subtitleURL {
                print("[Download] Found subtitle URL: \(subtitleURL.absoluteString)")
            }
            
            startActualDownload(url: url, streamUrl: streams[0], downloadID: downloadID, subtitleURL: subtitleURL)
        } else {
            // No valid streams from this method, try the next one
            print("[Download] Method #\(methodIndex+1) did not return valid streams, trying next method")
            tryNextDownloadMethod(methodIndex: methodIndex + 1, downloadID: downloadID, softsub: softsub)
        }
    }
    
    // Start the actual download process once we have a valid URL
    private func startActualDownload(url: URL, streamUrl: String, downloadID: UUID, subtitleURL: URL? = nil) {
        // Extract base URL for headers
        var headers: [String: String] = [:]
        
        // Always use the module's baseUrl for Origin and Referer
        if !module.metadata.baseUrl.isEmpty && !module.metadata.baseUrl.contains("undefined") {
            print("Using module baseUrl: \(module.metadata.baseUrl)")
            
            // Create comprehensive headers prioritizing the module's baseUrl
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
            // Fallback to using the stream URL's domain if module.baseUrl isn't available
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
                // Missing URL components
                DropManager.shared.error("Invalid stream URL - missing scheme or host")
                isDownloading = false
                return
            }
        }
        
        print("Download headers: \(headers)")
        
        // Get the image URL for the episode
        let episodeImg = episodeImageUrl.isEmpty ? defaultBannerImage : episodeImageUrl
        let imageURL = URL(string: episodeImg)
        
        // Get the episode title and information
        let episodeName = episodeTitle.isEmpty ? "Episode \(episodeID + 1)" : episodeTitle
        let fullEpisodeTitle = "Episode \(episodeID + 1): \(episodeName)"
        
        // Extract show title from the parent view
        let animeTitle = parentTitle.isEmpty ? "Unknown Anime" : parentTitle
        
        // Use jsController to handle the download with comprehensive headers and metadata
        jsController.startDownload(
            url: url,
            headers: headers,
            title: fullEpisodeTitle,
            imageURL: imageURL,
            isEpisode: true,
            showTitle: animeTitle,
            season: 1, // Default to season 1 if not known
            episode: episodeID + 1,
            subtitleURL: subtitleURL,
            completionHandler: { success, message in
                if success {
                    DropManager.shared.success("Download started for Episode \(self.episodeID + 1)")
                    
                    // Log the download for analytics
                    Logger.shared.log("Started download for Episode \(self.episodeID + 1): \(self.episode)", type: "Download")
                    AnalyticsManager.shared.sendEvent(
                        event: "download",
                        additionalData: ["episode": self.episodeID + 1, "url": streamUrl]
                    )
                } else {
                    DropManager.shared.error(message)
                }
                
                // Mark that we've handled this download
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
        // Check if metadata caching is enabled
        if MetadataCacheManager.shared.isCachingEnabled && 
           (UserDefaults.standard.object(forKey: "fetchEpisodeMetadata") == nil || 
           UserDefaults.standard.bool(forKey: "fetchEpisodeMetadata")) {
            
            // Create a cache key using the anilist ID and episode number
            let cacheKey = "anilist_\(itemID)_episode_\(episodeID + 1)"
            
            // Try to get from cache first
            if let cachedData = MetadataCacheManager.shared.getMetadata(forKey: cacheKey),
               let metadata = EpisodeMetadata.fromData(cachedData) {
                
                // Successfully loaded from cache
                DispatchQueue.main.async {
                    self.episodeTitle = metadata.title["en"] ?? ""
                    self.episodeImageUrl = metadata.imageUrl
                    self.isLoading = false
                    self.loadedFromCache = true
                    
                    Logger.shared.log("Loaded episode \(self.episodeID + 1) metadata from cache", type: "Debug")
                }
                return
            }
        }
        
        // Cache miss or caching disabled, fetch from network
        fetchAnimeEpisodeDetails()
    }
    
    private func fetchAnimeEpisodeDetails() {
        guard let url = URL(string: "https://api.ani.zip/mappings?anilist_id=\(itemID)") else {
            isLoading = false
            return
        }
        
        URLSession.custom.dataTask(with: url) { data, _, error in
            if let error = error {
                Logger.shared.log("Failed to fetch anime episode details: \(error)", type: "Error")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any],
                      let episodes = json["episodes"] as? [String: Any],
                      let episodeDetails = episodes["\(episodeID + 1)"] as? [String: Any],
                      let title = episodeDetails["title"] as? [String: String],
                      let image = episodeDetails["image"] as? String else {
                          Logger.shared.log("Invalid anime response format", type: "Error")
                          DispatchQueue.main.async { self.isLoading = false }
                          return
                      }
                
                // Cache the metadata if caching is enabled
                if MetadataCacheManager.shared.isCachingEnabled {
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
                    if UserDefaults.standard.object(forKey: "fetchEpisodeMetadata") == nil
                        || UserDefaults.standard.bool(forKey: "fetchEpisodeMetadata") {
                        self.episodeTitle   = title["en"] ?? ""
                        self.episodeImageUrl = image
                    }
                }
            } catch {
                DispatchQueue.main.async { self.isLoading = false }
            }
        }.resume()
    }
}
