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
    
    // Add retry configuration
    @State private var retryAttempts: Int = 0
    private let maxRetryAttempts: Int = 3
    private let initialBackoffDelay: TimeInterval = 1.0
    
    @ObservedObject private var jsController = JSController.shared
    @EnvironmentObject var moduleManager: ModuleManager
    
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedAppearance") private var selectedAppearance: Appearance = .system
    
    // Computed property to create a string representation of download status
    private var downloadStatusString: String {
        switch downloadStatus {
        case .notDownloaded:
            return "notDownloaded"
        case .downloading(let download):
            return "downloading_\(download.id)_\(Int(download.progress * 100))"
        case .downloaded(let asset):
            return "downloaded_\(asset.id)"
        }
    }
    
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
            // Stagger operations for better scroll performance
            updateProgress()
            
            // Always check download status when cell appears
            updateDownloadStatus()
            
            // Slightly delay loading episode details to prioritize smooth scrolling
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                fetchEpisodeDetails()
                observeDownloadProgress()
            }
            
            // Prefetch next episodes when this one becomes visible
            if let totalEpisodes = totalEpisodes, episodeID + 1 < totalEpisodes {
                // Prefetch the next 5 episodes when this one appears
                let nextEpisodeStart = episodeID + 1
                let count = min(5, totalEpisodes - episodeID - 1)
                
                // Also prefetch images for the next few episodes
                // Commented out prefetching until ImagePrefetchManager is ready
                // ImagePrefetchManager.shared.prefetchEpisodeImages(
                //     anilistId: itemID,
                //     startEpisode: nextEpisodeStart,
                //     count: count
                // )
            }
        }
        .onDisappear {
            activeDownloadTask = nil
        }
        .onChange(of: progress) { _ in
            updateProgress()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("downloadStatusChanged"))) { _ in
            // Always update download status for critical notifications
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
        .id("\(episode)_\(downloadRefreshTrigger)_\(downloadStatusString)")
    }
    
    // MARK: - View Components
    
    private var episodeThumbnail: some View {
        ZStack {
            if let url = URL(string: episodeImageUrl.isEmpty ? defaultBannerImage : episodeImageUrl) {
                KFImage.optimizedEpisodeThumbnail(url: url)
                    // Convert back to the regular KFImage since the extension isn't available yet
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 100, height: 56)))
                    .memoryCacheExpiration(.seconds(600)) // Increase cache duration to reduce loading
                    .cacheOriginalImage()
                    .fade(duration: 0.1) // Shorter fade for better performance
                    .onFailure { error in
                        Logger.shared.log("Failed to load episode image: \(error)", type: "Error")
                    }
                    .cacheMemoryOnly(!KingfisherCacheManager.shared.isCachingEnabled)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 100, height: 56)
                    .cornerRadius(8)
                    .onAppear {
                        // Image loading logic if needed
                    }
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
            let clampedProgress = min(max(downloadProgress, 0.0), 1.0)
            Text("\(Int(clampedProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressView(value: clampedProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 40)
        }
        .padding(.horizontal, 8)
        // Use a stable ID based on rounded progress to reduce updates
        .id("progress_\(Int(downloadProgress * 5) * 20)")
    }
    
    private var downloadedIndicator: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
            .font(.title3)
            .padding(.horizontal, 8)
            // Add animation to stand out more
            .scaleEffect(1.1)
            // Use more straightforward animation
            .animation(.default, value: downloadStatusString)
    }
    
    private var queuedIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.orange)
                .font(.caption)
            
            Text("Queued")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
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
        // Update the last status check time
        lastStatusCheck = Date()
        
        // Get the previous status before updating
        let previousStatus = downloadStatus
        
        // Check the current download status with JSController
        downloadStatus = jsController.isEpisodeDownloadedOrInProgress(
            showTitle: parentTitle,
            episodeNumber: episodeID + 1
        )
        
        // Update UI for any status change or force update if requested
        let statusChanged = previousStatus != downloadStatus
        if statusChanged {
            lastLoggedStatus = downloadStatus
            
            // Ensure UI updates with the new status by toggling refresh trigger
            downloadRefreshTrigger.toggle()
            
            // Update download progress when status changes
            if case .downloading(let activeDownload) = downloadStatus {
                // Store the active download task for direct progress observation
                activeDownloadTask = activeDownload.task
                
                // Update our local download progress state
                let newProgress = activeDownload.progress
                let clampedProgress = min(max(newProgress, 0.0), 1.0)
                
                // Progress has changed, update state
                downloadProgress = clampedProgress
                lastUpdateTime = Date() // Update timestamp
                
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
                        }
                    } else {
                    }
                }
            } else if case .downloaded = downloadStatus {
                // If we have a downloaded asset, ensure we show the checkmark
                downloadProgress = 1.0
            } else {
                // Reset download progress if no longer downloading
                downloadProgress = 0.0
                lastUpdateTime = Date() // Update timestamp
                
                // Clear the active download task
                activeDownloadTask = nil
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
                  episodeNumber == self.episodeID + 1 else {
                return
            }
            
            // Check if there's a status update
            if let status = userInfo["status"] as? String {
                // Special case for completed downloads - always update immediately
                if status == "completed" {
                    self.downloadProgress = 1.0
                    self.updateDownloadStatus() // Force check for downloaded status
                    self.downloadRefreshTrigger.toggle()
                    return
                }
                
                // For normal status updates
                self.updateDownloadStatus()
                
                // For queued status, we don't need to update progress
                if status == "queued" {
                    return
                }
            }
            
            if let progress = userInfo["progress"] as? Double {
                // Balance between responsiveness and performance:
                // - Update faster at start and end of download (20% and when complete)
                // - Update less frequently in the middle
                let shouldUpdateMore = (progress < 0.2 || progress > 0.95)
                let threshold = shouldUpdateMore ? 0.03 : 0.05 // 3% or 5% change
                
                if abs(progress - self.downloadProgress) > threshold {
                    self.downloadProgress = progress
                    self.lastUpdateTime = Date()
                    
                    // Only toggle on significant changes to avoid excessive view rebuilds
                    self.downloadRefreshTrigger.toggle()
                    
                    // If progress is 100%, ensure we show the downloaded state
                    if progress >= 1.0 {
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
    private func handleSequentialDownloadResult(_ result: (streams: [String]?, subtitles: [String]?, sources: [[String:Any]]?), downloadID: UUID, methodIndex: Int, softsub: Bool) {
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
        } else if let sources = result.sources, !sources.isEmpty, 
                  let streamUrl = sources[0]["streamUrl"] as? String, 
                  let url = URL(string: streamUrl) {
            
            print("[Download] Method #\(methodIndex+1) returned valid stream URL with headers: \(streamUrl)")
            
            // Get subtitle URL if available
            let subtitleURLString = sources[0]["subtitle"] as? String
            let subtitleURL = subtitleURLString.flatMap { URL(string: $0) }
            if let subtitleURL = subtitleURL {
                print("[Download] Found subtitle URL: \(subtitleURL.absoluteString)")
            }
            
            startActualDownload(url: url, streamUrl: streamUrl, downloadID: downloadID, subtitleURL: subtitleURL)
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
        
        // Use streamType-aware download method instead of M3U8-specific method
        jsController.downloadWithStreamTypeSupport(
            url: url,
            headers: headers,
            title: fullEpisodeTitle,
            imageURL: imageURL,
            module: module,
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
            Logger.shared.log("Invalid URL for itemID: \(itemID)", type: "Error")
            return
        }
        
        // For debugging
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
                
                // Check if episodes object exists
                guard let episodes = json["episodes"] as? [String: Any] else {
                    Logger.shared.log("Missing 'episodes' object in response", type: "Error")
                    // Still proceed with empty data rather than failing
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.retryAttempts = 0
                    }
                    return
                }
                
                // Check if this specific episode exists in the response
                let episodeKey = "\(episodeID + 1)"
                guard let episodeDetails = episodes[episodeKey] as? [String: Any] else {
                    Logger.shared.log("Episode \(episodeKey) not found in response", type: "Error")
                    // Still proceed with empty data rather than failing
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.retryAttempts = 0
                    }
                    return
                }
                
                // Extract available fields, log if they're missing but continue anyway
                var title: [String: String] = [:]
                var image: String = ""
                var missingFields: [String] = []
                
                if let titleData = episodeDetails["title"] as? [String: String], !titleData.isEmpty {
                    title = titleData
                    
                    // Check if we have any non-empty title values
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
                
                // Log missing fields but continue processing
                if !missingFields.isEmpty {
                    Logger.shared.log("Episode \(episodeKey) missing fields: \(missingFields.joined(separator: ", "))", type: "Warning")
                }
                
                // Cache whatever metadata we have if caching is enabled
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
                
                // Update UI with whatever data we have
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.retryAttempts = 0 // Reset retry counter on success (even partial)
                    
                    if UserDefaults.standard.object(forKey: "fetchEpisodeMetadata") == nil
                        || UserDefaults.standard.bool(forKey: "fetchEpisodeMetadata") {
                        // Use whatever title we have, or leave as empty string
                        self.episodeTitle = title["en"] ?? title.values.first ?? ""
                        
                        // Use image if available, otherwise leave current value
                        if !image.isEmpty {
                            self.episodeImageUrl = image
                        }
                    }
                }
            } catch {
                Logger.shared.log("JSON parsing error: \(error.localizedDescription)", type: "Error")
                // Still continue with empty data rather than failing
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
            // Check if we should retry
            if self.retryAttempts < self.maxRetryAttempts {
                // Increment retry counter
                self.retryAttempts += 1
                
                // Calculate backoff delay with exponential backoff
                let backoffDelay = self.initialBackoffDelay * pow(2.0, Double(self.retryAttempts - 1))
                
                Logger.shared.log("Will retry episode details fetch in \(backoffDelay) seconds", type: "Debug")
                
                // Schedule retry after backoff delay
                DispatchQueue.main.asyncAfter(deadline: .now() + backoffDelay) {
                    self.fetchAnimeEpisodeDetails()
                }
            } else {
                // Max retries reached, give up but still update UI with what we have
                Logger.shared.log("Failed to fetch episode details after \(self.maxRetryAttempts) attempts", type: "Error")
                self.isLoading = false
                self.retryAttempts = 0
            }
        }
    }
}
