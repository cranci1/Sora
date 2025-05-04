//
//  DownloadManager.swift
//  Sulfur
//
//  Created by Francesco on 29/04/25.
//

import SwiftUI
import AVKit
import AVFoundation
import Foundation

class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
    @Published var activeDownloads: [ActiveDownload] = []
    @Published var savedEpisodes: [DownloadedEpisode] = []
    @Published var queuedDownloads: [DownloadableEpisode] = []
    
    @Published var totalStorageUsed: Int64 = 0
    @Published var storageLimit: Int64 = 10 * 1024 * 1024 * 1024 // 10GB default limit
    @Published var storageWarningThreshold: Double = 0.9 // 90% of limit
    
    @AppStorage("autoCleanupEnabled") private var autoCleanupEnabled: Bool = true
    @AppStorage("cleanupThreshold") private var cleanupThreshold: Double = 0.8 // 80% threshold
    
    private var assetDownloadURLSession: AVAssetDownloadURLSession!
    private var activeDownloadTasks: [URLSessionTask: UUID] = [:]
    private var moduleHeaders: [String: [String: String]] = [:]  
    
    // Common user agent for all requests
    private let standardUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"
    
    // Settings
    private var maxConcurrentDownloads: Int {
        UserDefaults.standard.integer(forKey: "maxConcurrentDownloads") != 0 ? 
        UserDefaults.standard.integer(forKey: "maxConcurrentDownloads") : 3
    }
    
    private var allowCellularDownloads: Bool {
        UserDefaults.standard.object(forKey: "allowCellularDownloads") != nil ?
        UserDefaults.standard.bool(forKey: "allowCellularDownloads") : true
    }
    
    private var downloadQuality: String {
        UserDefaults.standard.string(forKey: "downloadQuality") ?? "Best"
    }
    
    private var downloadLocation: String {
        UserDefaults.standard.string(forKey: "downloadLocation") ?? "Documents"
    }
    
    private var autoStartDownloads: Bool {
        UserDefaults.standard.object(forKey: "autoStartDownloads") != nil ?
        UserDefaults.standard.bool(forKey: "autoStartDownloads") : true
    }
    
    private var deleteWatchedDownloads: Bool {
        UserDefaults.standard.bool(forKey: "deleteWatchedDownloads")
    }
    
    override init() {
        super.init()
        initializeDownloadSession()
        loadSavedEpisodes()
        initializeModuleHeaders()
        reconcileFileSystemAssets()
        setupWatchedDownloadsCleanup()
        setupStorageMonitoring()
        
        // Listen for module changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(modulesChanged),
            name: NSNotification.Name("ModulesChanged"),
            object: nil
        )
    }
    
    @objc private func modulesChanged() {
        // Reinitialize module headers when modules change
        initializeModuleHeaders()
        Logger.shared.log("Reinitialized module headers after modules changed", type: "Download")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func initializeModuleHeaders() {
        // Clear existing headers
        moduleHeaders.removeAll()
        
        // Add default headers
        moduleHeaders["default"] = [
            "Origin": "https://example.com",
            "Referer": "https://example.com"
        ]
        
        let moduleManager = ModuleManager()
        for module in moduleManager.modules {
            let headers = [
                "Origin": module.metadata.baseUrl,
                "Referer": module.metadata.baseUrl
            ]
            moduleHeaders[module.metadata.sourceName] = headers
            Logger.shared.log("Initialized headers for module: \(module.metadata.sourceName) with baseUrl: \(module.metadata.baseUrl)", type: "Download")
        }
        
        // Log the total number of modules with headers
        Logger.shared.log("Initialized headers for \(moduleHeaders.count - 1) modules (plus default)", type: "Download")
    }
    
    private func initializeDownloadSession() {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.sora.hls-downloader")
        configuration.allowsCellularAccess = allowCellularDownloads
        configuration.sessionSendsLaunchEvents = true
        
        assetDownloadURLSession = AVAssetDownloadURLSession(
            configuration: configuration,
            assetDownloadDelegate: self,
            delegateQueue: .main
        )
    }
    
    // MARK: - Public methods
    
    private func parseM3U8(url: URL, headers: [String: String]) async throws -> (URL, [URL]) {
        // Create a URLRequest with the appropriate headers
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Ensure we're adding a user agent if not already present
        if headers["User-Agent"] == nil {
            request.addValue(standardUserAgent, forHTTPHeaderField: "User-Agent")
        }
        
        // Log the request details for debugging
        Logger.shared.log("Fetching M3U8 from URL: \(url.absoluteString)", type: "Download")
        Logger.shared.log("Using headers: \(request.allHTTPHeaderFields ?? [:])", type: "Download")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response status code for debugging
        if let httpResponse = response as? HTTPURLResponse {
            Logger.shared.log("M3U8 fetch response code: \(httpResponse.statusCode)", type: "Download")
            
            if httpResponse.statusCode != 200 {
                throw NSError(domain: "DownloadManager", code: httpResponse.statusCode, 
                              userInfo: [NSLocalizedDescriptionKey: "Failed to fetch m3u8 with status code \(httpResponse.statusCode)"])
            }
        }
        
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "DownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode m3u8 content"])
        }
        
        // Log first few lines of the m3u8 for debugging
        let firstFewLines = content.components(separatedBy: .newlines).prefix(5).joined(separator: "\n")
        Logger.shared.log("M3U8 content preview: \n\(firstFewLines)", type: "Download")
        
        let lines = content.components(separatedBy: .newlines)
        var bestQualityURL: URL?
        var bestQuality = 0
        var segmentURLs: [URL] = []
        
        // Check if this is a master playlist or a media playlist
        let isMasterPlaylist = lines.contains { $0.contains("#EXT-X-STREAM-INF") }
        
        if isMasterPlaylist {
            // Parse master playlist for quality selection
            for (index, line) in lines.enumerated() {
                if line.contains("#EXT-X-STREAM-INF"), index + 1 < lines.count {
                    if let resolutionRange = line.range(of: "RESOLUTION="),
                       let resolutionEndRange = line[resolutionRange.upperBound...].range(of: ",")
                        ?? line[resolutionRange.upperBound...].range(of: "\n") {
                        
                        let resolutionPart = String(line[resolutionRange.upperBound..<resolutionEndRange.lowerBound])
                        if let heightStr = resolutionPart.components(separatedBy: "x").last,
                           let height = Int(heightStr),
                           height > bestQuality {
                            
                            let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                            var qualityURL = nextLine
                            
                            if !nextLine.hasPrefix("http") {
                                let baseURL = url.deletingLastPathComponent()
                                qualityURL = URL(string: nextLine, relativeTo: baseURL)?.absoluteString ?? nextLine
                            }
                            
                            if let url = URL(string: qualityURL) {
                                bestQualityURL = url
                                bestQuality = height
                            }
                        }
                    }
                }
            }
            
            // If we found a quality URL, parse its segments
            if let qualityURL = bestQualityURL {
                Logger.shared.log("Selected quality URL: \(qualityURL.absoluteString) with height: \(bestQuality)", type: "Download")
                let (_, segments) = try await parseM3U8(url: qualityURL, headers: headers)
                segmentURLs = segments
            }
        } else {
            // Parse media playlist for segments
            for line in lines {
                if line.hasPrefix("#EXTINF:") || line.isEmpty || line.hasPrefix("#") {
                    continue
                }
                
                var segmentURL = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !segmentURL.hasPrefix("http") {
                    let baseURL = url.deletingLastPathComponent()
                    segmentURL = URL(string: segmentURL, relativeTo: baseURL)?.absoluteString ?? segmentURL
                }
                
                if let url = URL(string: segmentURL) {
                    segmentURLs.append(url)
                }
            }
        }
        
        Logger.shared.log("Found \(segmentURLs.count) segments in M3U8", type: "Download")
        return (bestQualityURL ?? url, segmentURLs)
    }
    
    private func downloadSegment(_ segmentURL: URL, headers: [String: String], to destinationURL: URL) async throws {
        // Create a request with the appropriate headers
        var request = URLRequest(url: segmentURL)
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Ensure we're adding a user agent if not already present
        if headers["User-Agent"] == nil {
            request.addValue(standardUserAgent, forHTTPHeaderField: "User-Agent")
        }
        
        // Log segment download attempt (only log the filename part to avoid spam)
        let segmentName = segmentURL.lastPathComponent
        Logger.shared.log("Downloading segment: \(segmentName)", type: "Download")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            Logger.shared.log("Failed to download segment \(segmentName) with status code \(statusCode)", type: "Error")
            throw NSError(domain: "DownloadManager", code: statusCode, 
                          userInfo: [NSLocalizedDescriptionKey: "Failed to download segment with status code \(statusCode)"])
        }
        
        // Write the segment to disk
        try data.write(to: destinationURL)
        
        // Log success for debugging
        Logger.shared.log("Successfully saved segment: \(segmentName) (\(data.count) bytes)", type: "Download")
    }
    
    /// Download an episode from a stream URL
    func downloadEpisode(_ episode: DownloadableEpisode) {
        Logger.shared.log("Starting download for episode: \(episode.title)", type: "Download")
        Logger.shared.log("Stream URL: \(episode.streamURL)", type: "Download")
        Logger.shared.log("Module type: \(episode.moduleType)", type: "Download")
        
        // For m3u8 and mp4 streams, proceed directly with download
        let streamURL = episode.streamURL.absoluteString
        if streamURL.contains(".m3u8") || streamURL.contains(".mp4") {
            let fileType = streamURL.contains(".m3u8") ? "m3u8" : "mp4"
            Logger.shared.log("Direct \(fileType) stream detected, starting download", type: "Download")
            startDownload(episode)
            return
        }
        
        // Get the module for this episode
        let moduleManager = ModuleManager()
        guard let module = moduleManager.modules.first(where: { $0.metadata.sourceName == episode.moduleType }) else {
            Logger.shared.log("No module found for type: \(episode.moduleType)", type: "Error")
            return
        }
        
        Logger.shared.log("Found matching module: \(module.metadata.sourceName)", type: "Download")
        
        // Register custom headers for this module using its baseUrl
        let customHeaders = [
            "Origin": module.metadata.baseUrl,
            "Referer": module.metadata.baseUrl
        ]
        registerHeaders(customHeaders, forModule: episode.moduleType)
        Logger.shared.log("Using custom headers from module baseUrl: \(module.metadata.baseUrl)", type: "Download")
        
        // Create a download context to track this attempt and the methods we've tried
        let downloadContext = DownloadContext(
            episode: episode,
            module: module,
            methodsToTry: determineMethodsToTry(module)
        )
        
        // Start the cascading download process with the first method
        tryDownloadWithNextMethod(context: downloadContext)
    }
    
    /// Directly download from an extracted stream URL
    func downloadFromStreamURL(streamUrl: String, episodeID: String, title: String, moduleType: String, episodeNumber: Int, imageURL: URL?, aniListID: Int = 0, headers: [String: String]? = nil) {
        Logger.shared.log("Directly downloading from stream URL: \(streamUrl)", type: "Download")
        
        guard let url = URL(string: streamUrl), (streamUrl.contains(".m3u8") || streamUrl.contains(".mp4")) else {
            Logger.shared.log("Invalid stream URL or not a supported format (.m3u8 or .mp4): \(streamUrl)", type: "Error")
            return
        }
        
        // Detect megacloud specifically in the URL
        var moduleTypeToUse = moduleType
        if streamUrl.contains("megacloud") || streamUrl.contains("vidplay") {
            moduleTypeToUse = "megacloud"
            Logger.shared.log("Detected megacloud URL, using megacloud module type", type: "Download")
        }
        
        // Get module from ModuleManager to access its baseUrl for headers
        let moduleManager = ModuleManager()
        
        // Register custom headers if provided, otherwise use headers from the module
        if let customHeaders = headers {
            Logger.shared.log("Using provided custom headers from successful playlist fetch", type: "Download")
            registerHeaders(customHeaders, forModule: moduleTypeToUse)
        } else if let module = moduleManager.modules.first(where: { $0.metadata.sourceName == moduleTypeToUse }) {
            // Register custom headers for this module using its baseUrl
            let customHeaders = [
                "Origin": module.metadata.baseUrl,
                "Referer": module.metadata.baseUrl
            ]
            registerHeaders(customHeaders, forModule: moduleTypeToUse)
            Logger.shared.log("Using custom headers from module baseUrl: \(module.metadata.baseUrl)", type: "Download")
        }
        
        let episode = DownloadableEpisode(
            episodeID: episodeID,
            title: title,
            moduleType: moduleTypeToUse,
            episodeNumber: episodeNumber,
            streamURL: url,
            imageURL: imageURL,
            aniListID: aniListID
        )
        
        // Start the download directly since we already have the stream URL
        startDownload(episode)
    }
    
    private func startDownload(_ episode: DownloadableEpisode) {
        Logger.shared.log("Starting download task for episode: \(episode.title)", type: "Download")
        
        // Prepare the stream URL with appropriate headers
        let (streamURL, headers) = prepareStreamForDownload(streamURL: episode.streamURL, moduleType: episode.moduleType)
        
        // Log detailed information about headers being used
        Logger.shared.log("Download headers: \(headers)", type: "Download")
        
        // Create AVURLAsset with custom headers
        let asset = AVURLAsset(url: streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        
        // Log the options for debugging
        Logger.shared.log("AVURLAsset created with options: \(["AVURLAssetHTTPHeaderFieldsKey": headers])", type: "Download")
        
        // Set download options based on quality setting
        var options: [String: Any] = [:]
        switch downloadQuality {
        case "Best":
            options[AVAssetDownloadTaskMinimumRequiredMediaBitrateKey] = NSNumber(value: 4_000_000)
        case "High":
            options[AVAssetDownloadTaskMinimumRequiredMediaBitrateKey] = NSNumber(value: 2_000_000)
        case "Medium":
            options[AVAssetDownloadTaskMinimumRequiredMediaBitrateKey] = NSNumber(value: 1_000_000)
        case "Low":
            options[AVAssetDownloadTaskMinimumRequiredMediaBitrateKey] = NSNumber(value: 500_000)
        default:
            options[AVAssetDownloadTaskMinimumRequiredMediaBitrateKey] = NSNumber(value: 2_000_000)
        }
        
        Logger.shared.log("Creating download task with quality: \(downloadQuality)", type: "Download")
        
        // Create download task
        let task = assetDownloadURLSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: episode.title,
            assetArtworkData: nil,
            options: options
        )
        
        guard let task = task else {
            Logger.shared.log("Failed to create download task for episode: \(episode.title)", type: "Error")
            return
        }
        
        Logger.shared.log("Successfully created download task", type: "Download")
        
        // Create active download record
        let activeDownload = ActiveDownload(
            id: UUID(),
            originalURL: episode.streamURL,
            progress: 0,
            moduleType: episode.moduleType,
            episodeNumber: episode.episodeNumber,
            title: episode.title,
            imageURL: episode.imageURL,
            dateStarted: Date(),
            episodeID: episode.episodeID,
            task: task
        )
        
        // Add to active downloads
        activeDownloads.append(activeDownload)
        activeDownloadTasks[task] = activeDownload.id
        
        // Start the download
        task.resume()
        Logger.shared.log("Download task started for episode: \(episode.title)", type: "Download")
    }
    
    func downloadAsset(from url: URL) {
        // Legacy method for backward compatibility
        let asset = AVURLAsset(url: url)
        let task = assetDownloadURLSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: "Offline Video",
            assetArtworkData: nil,
            options: nil
        )
        
        guard let task = task else { return }
        
        let download = ActiveDownload(
            id: UUID(),
            originalURL: url,
            progress: 0,
            moduleType: "default",
            episodeNumber: 1,
            title: url.lastPathComponent,
            imageURL: nil,
            dateStarted: Date(),
            episodeID: url.absoluteString,
            task: task
        )
        
        activeDownloads.append(download)
        activeDownloadTasks[task] = download.id
        task.resume()
    }
    
    /// Pause a download in progress
    func pauseDownload(_ download: ActiveDownload) {
        download.task?.suspend()
        
        // Update UI if needed
        if let index = activeDownloads.firstIndex(where: { $0.id == download.id }) {
            // We can't directly modify the task, so we create a new instance with the same properties
            let updatedDownload = download
            // Additional logic to update state if needed
            activeDownloads[index] = updatedDownload
        }
    }
    
    /// Resume a paused download
    func resumeDownload(_ download: ActiveDownload) {
        download.task?.resume()
        
        // Update UI if needed
        if let index = activeDownloads.firstIndex(where: { $0.id == download.id }) {
            // We can't directly modify the task, so we create a new instance with the same properties
            let updatedDownload = download
            // Additional logic to update state if needed
            activeDownloads[index] = updatedDownload
        }
    }
    
    /// Cancel an active download
    func cancelDownload(_ download: ActiveDownload) {
        download.task?.cancel()
        
        // Clean up
        if let task = download.task {
            activeDownloadTasks.removeValue(forKey: task)
        }
        activeDownloads.removeAll { $0.id == download.id }
    }
    
    /// Delete a downloaded episode and remove its file
    func deleteEpisode(_ episode: DownloadedEpisode) {
        do {
            try FileManager.default.removeItem(at: episode.localURL)
            savedEpisodes.removeAll { $0.id == episode.id }
            saveEpisodes()
        } catch {
            Logger.shared.log("Error deleting episode: \(error.localizedDescription)", type: "Error")
        }
    }
    
    /// Rename a downloaded episode
    func renameEpisode(_ episode: DownloadedEpisode, newName: String) {
        guard let index = savedEpisodes.firstIndex(where: { $0.id == episode.id }) else { return }
        savedEpisodes[index].title = newName
        saveEpisodes()
    }
    
    /// Register custom headers for a specific module
    func registerHeaders(_ headers: [String: String], forModule moduleType: String) {
        moduleHeaders[moduleType] = headers
    }
    
    /// Queue an episode for download
    func queueEpisode(_ episode: DownloadableEpisode) {
        Logger.shared.log("Attempting to queue episode: \(episode.title) (ID: \(episode.episodeID))", type: "Download")
        
        // Check if already downloaded, in progress, or queued
        if savedEpisodes.contains(where: { $0.episodeID == episode.episodeID }) {
            Logger.shared.log("Episode already downloaded: \(episode.title)", type: "Download")
            return
        }
        
        if activeDownloads.contains(where: { $0.episodeID == episode.episodeID }) {
            Logger.shared.log("Episode already being downloaded: \(episode.title)", type: "Download")
            return
        }
        
        if queuedDownloads.contains(where: { $0.episodeID == episode.episodeID }) {
            Logger.shared.log("Episode already queued: \(episode.title)", type: "Download")
            return
        }
        
        queuedDownloads.append(episode)
        Logger.shared.log("Successfully queued episode: \(episode.title)", type: "Download")
        
        if autoStartDownloads {
            Logger.shared.log("Auto-start enabled, processing next queued download", type: "Download")
            processNextQueuedDownload()
        }
    }
    
    /// Process the next queued download if there's space in the active downloads
    private func processNextQueuedDownload() {
        Logger.shared.log("Processing next queued download", type: "Download")
        Logger.shared.log("Active downloads count: \(activeDownloads.count), Max concurrent: \(maxConcurrentDownloads)", type: "Download")
        Logger.shared.log("Queued downloads count: \(queuedDownloads.count)", type: "Download")
        
        guard activeDownloads.count < maxConcurrentDownloads else {
            Logger.shared.log("Cannot process next download - max concurrent downloads reached", type: "Download")
            return
        }
        
        guard let nextEpisode = queuedDownloads.first else {
            Logger.shared.log("No queued downloads to process", type: "Download")
            return
        }
        
        Logger.shared.log("Processing queued download: \(nextEpisode.title)", type: "Download")
        queuedDownloads.removeFirst()
        downloadEpisode(nextEpisode)
    }
    
    /// Remove an episode from the queue
    func removeFromQueue(_ episode: DownloadableEpisode) {
        queuedDownloads.removeAll { $0.episodeID == episode.episodeID }
        Logger.shared.log("Removed episode from queue: \(episode.title)", type: "Download")
    }
    
    /// Move an episode up in the queue
    func moveUpInQueue(_ episode: DownloadableEpisode) {
        guard let index = queuedDownloads.firstIndex(where: { $0.episodeID == episode.episodeID }),
              index > 0 else {
            return
        }
        
        queuedDownloads.swapAt(index, index - 1)
        Logger.shared.log("Moved episode up in queue: \(episode.title)", type: "Download")
    }
    
    /// Move an episode down in the queue
    func moveDownInQueue(_ episode: DownloadableEpisode) {
        guard let index = queuedDownloads.firstIndex(where: { $0.episodeID == episode.episodeID }),
              index < queuedDownloads.count - 1 else {
            return
        }
        
        queuedDownloads.swapAt(index, index + 1)
        Logger.shared.log("Moved episode down in queue: \(episode.title)", type: "Download")
    }
    
    /// Pause all active downloads
    func pauseAllDownloads() {
        for download in activeDownloads {
            if let task = activeDownloadTasks.first(where: { $0.value == download.id })?.key {
                task.suspend()
            }
        }
        Logger.shared.log("Paused all active downloads", type: "Download")
    }
    
    /// Resume all paused downloads
    func resumeAllDownloads() {
        for download in activeDownloads {
            if let task = activeDownloadTasks.first(where: { $0.value == download.id })?.key {
                task.resume()
            }
        }
        Logger.shared.log("Resumed all paused downloads", type: "Download")
    }
    
    /// Cancel all active downloads
    func cancelAllDownloads() {
        for download in activeDownloads {
            if let task = activeDownloadTasks.first(where: { $0.value == download.id })?.key {
                task.cancel()
            }
        }
        activeDownloads.removeAll()
        Logger.shared.log("Cancelled all active downloads", type: "Download")
    }
    
    /// Clear the download queue
    func clearQueue() {
        queuedDownloads.removeAll()
        Logger.shared.log("Cleared download queue", type: "Download")
    }
    
    /// Prepares an m3u8 stream URL with appropriate headers for download
    func prepareStreamForDownload(streamURL: URL, moduleType: String) -> (URL, [String: String]) {
        // Prepare headers based on module type
        var headers = moduleHeaders[moduleType] ?? moduleHeaders["default"]!
        
        // Log the headers we're using for debugging
        Logger.shared.log("Using module-specific headers for download: \(moduleType)", type: "Download")
        
        // Add standard user agent if not already present
        if headers["User-Agent"] == nil {
            headers["User-Agent"] = standardUserAgent
        }
        
        // Ensure we log the details for debugging
        Logger.shared.log("Preparing stream URL: \(streamURL)", type: "Download")
        Logger.shared.log("Using headers: \(headers)", type: "Download")
        
        return (streamURL, headers)
    }
    
    // MARK: - Private methods
    
    private func saveEpisodes() {
        do {
            let data = try JSONEncoder().encode(savedEpisodes)
            UserDefaults.standard.set(data, forKey: "savedEpisodes")
        } catch {
            Logger.shared.log("Error saving episodes: \(error.localizedDescription)", type: "Error")
        }
    }
    
    private func loadSavedEpisodes() {
        guard let data = UserDefaults.standard.data(forKey: "savedEpisodes") else { return }
        do {
            savedEpisodes = try JSONDecoder().decode([DownloadedEpisode].self, from: data)
        } catch {
            Logger.shared.log("Error loading saved episodes: \(error.localizedDescription)", type: "Error")
        }
    }
    
    private func loadLocalContent() {
        // Legacy method for backward compatibility
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: documents,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            
            if let localURL = contents.first(where: { $0.pathExtension == "movpkg" }) {
                // If we find movpkg files, make sure they're in our savedEpisodes list
                if !savedEpisodes.contains(where: { $0.localURL == localURL }) {
                    let newEpisode = DownloadedEpisode(
                        title: localURL.deletingPathExtension().lastPathComponent,
                        moduleType: "unknown",
                        episodeNumber: 1,
                        downloadDate: Date(),
                        originalURL: localURL,
                        localURL: localURL,
                        imageURL: nil,
                        episodeID: localURL.lastPathComponent,
                        aniListID: nil
                    )
                    savedEpisodes.append(newEpisode)
                    saveEpisodes()
                }
            }
        } catch {
            print("Error loading local content: \(error)")
        }
    }
    
    private func reconcileFileSystemAssets() {
        let location = downloadLocation == "Cache" ? 
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first :
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        
        guard let directoryURL = location else { return }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            // Find .movpkg files that aren't in savedEpisodes
            for url in fileURLs where url.pathExtension == "movpkg" {
                if !savedEpisodes.contains(where: { $0.localURL == url }) {
                    // Create a new episode entry for unknown files
                    let newEpisode = DownloadedEpisode(
                        title: url.deletingPathExtension().lastPathComponent,
                        moduleType: "unknown",
                        episodeNumber: 1, // Default
                        downloadDate: Date(),
                        originalURL: url, // This is a fallback
                        localURL: url,
                        imageURL: nil,
                        episodeID: url.lastPathComponent,
                        aniListID: nil
                    )
                    savedEpisodes.append(newEpisode)
                }
            }
            saveEpisodes()
        } catch {
            Logger.shared.log("Error reconciling files: \(error.localizedDescription)", type: "Error")
        }
    }
    
    private func cleanupDownloadTask(_ task: URLSessionTask) {
        guard let downloadID = activeDownloadTasks[task] else { return }
        
        activeDownloadTasks.removeValue(forKey: task)
        activeDownloads.removeAll { $0.id == downloadID }
    }
    
    private func setupWatchedDownloadsCleanup() {
        // Only set up if the feature is enabled
        if deleteWatchedDownloads {
            // Check every hour for fully watched episodes to clean up
            Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
                self?.cleanupWatchedDownloads()
            }
        }
    }
    
    private func cleanupWatchedDownloads() {
        guard deleteWatchedDownloads else { return }
        
        for episode in savedEpisodes {
            let progress = getWatchProgress(for: episode.episodeID)
            // If progress is over 95%, we consider it fully watched
            if progress >= 0.95 {
                Logger.shared.log("Auto-deleting watched episode: \(episode.title)", type: "Info")
                deleteEpisode(episode)
            }
        }
    }
    
    private func getWatchProgress(for episodeID: String) -> Double {
        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(episodeID)")
        let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(episodeID)")
        return totalTime > 0 ? min(lastPlayedTime / totalTime, 1.0) : 0
    }
    
    // MARK: - Storage Management
    
    private func setupStorageMonitoring() {
        // Update storage usage every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.updateStorageUsage()
        }
        updateStorageUsage()
    }
    
    func updateStorageUsage() {
        let location = downloadLocation == "Cache" ? 
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first :
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        
        guard let directoryURL = location else { return }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            let totalSize = fileURLs.reduce(0) { total, url in
                do {
                    let values = try url.resourceValues(forKeys: [.fileSizeKey])
                    return total + (values.fileSize ?? 0)
                } catch {
                    return total
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.totalStorageUsed = Int64(totalSize)
                self?.checkStorageLimits()
            }
        } catch {
            Logger.shared.log("Error calculating storage usage: \(error.localizedDescription)", type: "Error")
        }
    }
    
    private func checkStorageLimits() {
        // Ensure storage limit is at least 1GB to avoid division by zero
        if storageLimit <= 0 {
            storageLimit = 1024 * 1024 * 1024 // 1GB
        }
        
        let usagePercentage = Double(totalStorageUsed) / Double(storageLimit)
        
        if usagePercentage >= storageWarningThreshold {
            NotificationCenter.default.post(
                name: .DownloadManagerStatusUpdate,
                object: nil,
                userInfo: ["type": "storageWarning", "usage": usagePercentage]
            )
            Logger.shared.log("Storage usage warning: \(String(format: "%.1f", usagePercentage * 100))%", type: "Warning")
            
            if autoCleanupEnabled && usagePercentage >= cleanupThreshold {
                performStorageCleanup()
            }
        }
    }
    
    private func performStorageCleanup() {
        Logger.shared.log("Initiating storage cleanup", type: "Info")
        
        // Sort episodes by last watched date (oldest first)
        let sortedEpisodes = savedEpisodes.sorted { episode1, episode2 in
            let progress1 = getWatchProgress(for: episode1.episodeID)
            let progress2 = getWatchProgress(for: episode2.episodeID)
            
            // First, prioritize fully watched episodes
            if progress1 >= 0.95 && progress2 < 0.95 {
                return true
            }
            if progress1 < 0.95 && progress2 >= 0.95 {
                return false
            }
            
            // Then sort by file size (largest first)
            return (episode1.fileSize ?? 0) > (episode2.fileSize ?? 0)
        }
        
        let spaceToFree = Int64(Double(storageLimit) * 0.2) // Try to free 20% of storage
        var freedSpace: Int64 = 0
        
        for episode in sortedEpisodes {
            if freedSpace >= spaceToFree {
                break
            }
            
            if let fileSize = episode.fileSize {
                deleteEpisode(episode)
                freedSpace += fileSize
                Logger.shared.log("Deleted episode to free space: \(episode.title)", type: "Info")
            }
        }
        
        if freedSpace > 0 {
            Logger.shared.log("Freed \(formatFileSize(freedSpace)) of storage space", type: "Info")
            NotificationCenter.default.post(
                name: .DownloadManagerStatusUpdate,
                object: nil,
                userInfo: ["type": "storageCleanup", "freedSpace": freedSpace]
            )
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    func setStorageLimit(_ limit: Int64) {
        storageLimit = limit
        checkStorageLimits()
    }
    
    func getStorageUsagePercentage() -> Double {
        return Double(totalStorageUsed) / Double(storageLimit)
    }
    
    func getAvailableStorage() -> Int64 {
        return max(0, storageLimit - totalStorageUsed)
    }
    
    func canDownloadEpisode(_ episode: DownloadableEpisode) -> Bool {
        // Estimate the episode size (this is a rough estimate)
        let estimatedSize: Int64 = 500 * 1024 * 1024 // 500MB per episode
        return getAvailableStorage() >= estimatedSize
    }
    
    // Helper struct to track the state of a download attempt
    private struct DownloadContext {
        let episode: DownloadableEpisode
        let module: ScrapingModule
        var methodsToTry: [StreamFetchMethod]
        var jsController: JSController? = nil
        
        init(episode: DownloadableEpisode, module: ScrapingModule, methodsToTry: [StreamFetchMethod]) {
            self.episode = episode
            self.module = module
            self.methodsToTry = methodsToTry
            self.jsController = JSController()
        }
    }
    
    // Enum to track which fetch methods to try and in what order
    private enum StreamFetchMethod {
        case asyncJS(softsub: Bool)
        case asyncJSSecond(softsub: Bool)
        case sync(softsub: Bool)
    }
    
    // Determine which methods to try based on module metadata
    private func determineMethodsToTry(_ module: ScrapingModule) -> [StreamFetchMethod] {
        var methods: [StreamFetchMethod] = []
        let hasSoftsub = module.metadata.softsub ?? false
        
        // Add methods in priority order
        if module.metadata.asyncJS == true {
            methods.append(.asyncJS(softsub: hasSoftsub))
        }
        
        if module.metadata.streamAsyncJS == true {
            methods.append(.asyncJSSecond(softsub: hasSoftsub))
        }
        
        // Always add sync method as a fallback
        methods.append(.sync(softsub: hasSoftsub))
        
        return methods
    }
    
    // Try each download method in sequence, falling back to the next one if needed
    private func tryDownloadWithNextMethod(context: DownloadContext) {
        var mutableContext = context
        
        // If no more methods to try, give up
        guard !mutableContext.methodsToTry.isEmpty else {
            Logger.shared.log("All stream fetch methods failed for episode: \(context.episode.title)", type: "Error")
            return
        }
        
        // Get the next method to try
        let method = mutableContext.methodsToTry.removeFirst()
        
        // Create JS controller if needed
        if mutableContext.jsController == nil {
            mutableContext.jsController = JSController()
        }
        
        guard let jsController = mutableContext.jsController else {
            Logger.shared.log("Failed to create JS controller", type: "Error")
            return
        }
        
        // Load the module's JavaScript content
        do {
            let moduleManager = ModuleManager()
            let jsContent = try moduleManager.getModuleContent(mutableContext.module)
            jsController.loadScript(jsContent)
        } catch {
            Logger.shared.log("Error loading module content: \(error)", type: "Error")
            return
        }
        
        // Try the current method
        switch method {
        case .asyncJS(let softsub):
            Logger.shared.log("Trying asyncJS method with softsub: \(softsub)", type: "Download")
            jsController.fetchStreamUrlJS(
                episodeUrl: context.episode.streamURL.absoluteString,
                softsub: softsub,
                module: context.module
            ) { [weak self] result in
                if let streams = result.streams, !streams.isEmpty {
                    Logger.shared.log("asyncJS method succeeded with \(streams.count) streams", type: "Download")
                    self?.processSuccessfulStreamResult(result, context: context)
                } else {
                    Logger.shared.log("asyncJS method failed, trying next method", type: "Download")
                    self?.tryDownloadWithNextMethod(context: mutableContext)
                }
            }
            
        case .asyncJSSecond(let softsub):
            Logger.shared.log("Trying asyncJSSecond method with softsub: \(softsub)", type: "Download")
            jsController.fetchStreamUrlJSSecond(
                episodeUrl: context.episode.streamURL.absoluteString,
                softsub: softsub,
                module: context.module
            ) { [weak self] result in
                if let streams = result.streams, !streams.isEmpty {
                    Logger.shared.log("asyncJSSecond method succeeded with \(streams.count) streams", type: "Download")
                    self?.processSuccessfulStreamResult(result, context: context)
                } else {
                    Logger.shared.log("asyncJSSecond method failed, trying next method", type: "Download")
                    self?.tryDownloadWithNextMethod(context: mutableContext)
                }
            }
            
        case .sync(let softsub):
            Logger.shared.log("Trying sync method with softsub: \(softsub)", type: "Download")
            jsController.fetchStreamUrl(
                episodeUrl: context.episode.streamURL.absoluteString,
                softsub: softsub,
                module: context.module
            ) { [weak self] result in
                if let streams = result.streams, !streams.isEmpty {
                    Logger.shared.log("sync method succeeded with \(streams.count) streams", type: "Download")
                    self?.processSuccessfulStreamResult(result, context: context)
                } else {
                    Logger.shared.log("sync method failed, trying next method", type: "Download")
                    self?.tryDownloadWithNextMethod(context: mutableContext)
                }
            }
        }
    }
    
    // Process successful stream result
    private func processSuccessfulStreamResult(_ result: (streams: [String]?, subtitles: [String]?), context: DownloadContext) {
        guard let streams = result.streams, !streams.isEmpty else {
            Logger.shared.log("No streams found in result", type: "Error")
            return
        }
        
        // Prioritize m3u8 streams first, then mp4 streams
        let m3u8Streams = streams.filter { $0.contains(".m3u8") }
        let mp4Streams = streams.filter { $0.contains(".mp4") }
        let streamUrl = m3u8Streams.first ?? mp4Streams.first ?? streams.first ?? ""
        
        if streamUrl.isEmpty {
            Logger.shared.log("No valid stream URL found", type: "Error")
            return
        }
        
        Logger.shared.log("Successfully fetched stream URL: \(streamUrl)", type: "Download")
        
        // If this is a master playlist, we need to extract the highest quality stream
        if streamUrl.contains("master.m3u8") || streamUrl.contains("playlist.m3u8") {
            Logger.shared.log("Detected master playlist, fetching highest quality stream", type: "Download")
            fetchHighestQualityStream(masterUrl: streamUrl, context: context)
        } else {
            // Direct stream URL, create episode and start download
            createAndStartDownload(streamUrl: streamUrl, context: context)
        }
    }
    
    // Fetch the highest quality stream from a master playlist
    private func fetchHighestQualityStream(masterUrl: String, context: DownloadContext) {
        guard let url = URL(string: masterUrl) else {
            Logger.shared.log("Invalid master playlist URL", type: "Error")
            return
        }
        
        // Get the appropriate headers for this module type
        let headers = moduleHeaders[context.module.metadata.sourceName] ?? moduleHeaders["default"] ?? [:]
        
        // Create a request with the appropriate headers
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Ensure we're adding a user agent if not already present
        if headers["User-Agent"] == nil {
            request.addValue(standardUserAgent, forHTTPHeaderField: "User-Agent")
        }
        
        Logger.shared.log("Fetching master playlist from: \(masterUrl)", type: "Download")
        
        // Fetch the master playlist
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.shared.log("Error fetching master playlist: \(error.localizedDescription)", type: "Error")
                // Fall back to using the master URL directly
                self.createAndStartDownload(streamUrl: masterUrl, context: context)
                return
            }
            
            guard let data = data, let content = String(data: data, encoding: .utf8) else {
                Logger.shared.log("Could not decode master playlist content", type: "Error")
                // Fall back to using the master URL directly
                self.createAndStartDownload(streamUrl: masterUrl, context: context)
                return
            }
            
            // Parse the m3u8 master playlist
            let bestQualityUrl = self.parseMasterPlaylist(content: content, baseUrl: url)
            
            if let highQualityUrl = bestQualityUrl {
                Logger.shared.log("Found highest quality stream: \(highQualityUrl)", type: "Download")
                self.createAndStartDownload(streamUrl: highQualityUrl, context: context)
            } else {
                Logger.shared.log("Could not find stream in master playlist, using master URL directly", type: "Download")
                self.createAndStartDownload(streamUrl: masterUrl, context: context)
            }
        }.resume()
    }
    
    // Parse the master playlist to find the highest quality stream
    private func parseMasterPlaylist(content: String, baseUrl: URL) -> String? {
        let lines = content.components(separatedBy: .newlines)
        var bestQualityURL: String?
        var bestQuality = 0
        var bestBandwidth = 0
        
        // Log the first few lines for debugging
        let firstFewLines = lines.prefix(10).joined(separator: "\n")
        Logger.shared.log("Master playlist content (first 10 lines):\n\(firstFewLines)", type: "Download")
        
        for (index, line) in lines.enumerated() {
            if line.contains("#EXT-X-STREAM-INF"), index + 1 < lines.count {
                var quality = 0
                var bandwidth = 0
                
                // Extract resolution if available
                if let resolutionRange = line.range(of: "RESOLUTION=") {
                    let resolutionPart = line[resolutionRange.upperBound...]
                    if let resolutionEndRange = resolutionPart.range(of: ",") ?? resolutionPart.range(of: "\n") {
                        let resolution = String(resolutionPart[..<resolutionEndRange.lowerBound])
                        if let heightStr = resolution.components(separatedBy: "x").last?.trimmingCharacters(in: .whitespaces),
                           let height = Int(heightStr) {
                            quality = height
                        }
                    }
                }
                
                // Extract bandwidth if available
                if let bandwidthRange = line.range(of: "BANDWIDTH=") {
                    let bandwidthPart = line[bandwidthRange.upperBound...]
                    if let bandwidthEndRange = bandwidthPart.range(of: ",") ?? bandwidthPart.range(of: "\n") {
                        let bandwidthStr = String(bandwidthPart[..<bandwidthEndRange.lowerBound])
                        if let bw = Int(bandwidthStr.trimmingCharacters(in: .whitespaces)) {
                            bandwidth = bw
                        }
                    }
                }
                
                // If this stream has higher quality or bandwidth than the previous best, use it
                let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                if nextLine.isEmpty || nextLine.hasPrefix("#") {
                    continue
                }
                
                let useThisStream = false
                    || (quality > bestQuality) 
                    || (quality == bestQuality && bandwidth > bestBandwidth)
                
                if useThisStream {
                    var streamUrl = nextLine
                    
                    // Handle relative URLs
                    if !nextLine.hasPrefix("http") {
                        streamUrl = URL(string: nextLine, relativeTo: baseUrl)?.absoluteString ?? nextLine
                    }
                    
                    bestQualityURL = streamUrl
                    bestQuality = quality
                    bestBandwidth = bandwidth
                    
                    Logger.shared.log("Found better quality stream: Resolution=\(quality), Bandwidth=\(bandwidth), URL=\(streamUrl)", type: "Download")
                }
            }
        }
        
        return bestQualityURL
    }
    
    // Create episode and start download
    private func createAndStartDownload(streamUrl: String, context: DownloadContext) {
        guard let url = URL(string: streamUrl) else {
            Logger.shared.log("Invalid stream URL: \(streamUrl)", type: "Error")
            return
        }
        
        // Create a new DownloadableEpisode with the actual stream URL
        let episodeWithStream = DownloadableEpisode(
            episodeID: context.episode.episodeID,
            title: context.episode.title,
            moduleType: context.episode.moduleType,
            episodeNumber: context.episode.episodeNumber,
            streamURL: url,
            imageURL: context.episode.imageURL,
            aniListID: context.episode.aniListID
        )
        
        startDownload(episodeWithStream)
    }
}

extension DownloadManager: AVAssetDownloadDelegate {
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard let downloadID = activeDownloadTasks[assetDownloadTask],
              let activeDownload = activeDownloads.first(where: { $0.id == downloadID }) else {
            Logger.shared.log("Download completed but could not find active download record", type: "Error")
            return
        }
        
        Logger.shared.log("Download completed for \(activeDownload.title)", type: "Download")
        
        // If the download location preference is set to cache, we need to move the file
        var finalLocation = location
        if downloadLocation == "Cache" {
            if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let filename = location.lastPathComponent
                let destinationURL = cacheURL.appendingPathComponent(filename)
                
                Logger.shared.log("Moving downloaded file to cache directory", type: "Download")
                
                // Move the file to cache
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: location, to: destinationURL)
                    finalLocation = destinationURL
                    Logger.shared.log("Successfully moved download to cache location", type: "Download")
                } catch {
                    Logger.shared.log("Error moving download to cache: \(error.localizedDescription)", type: "Error")
                    // If we fail to move, use the original location
                }
            }
        }
        
        // Create a saved episode from the completed download
        let newEpisode = DownloadedEpisode(
            title: activeDownload.title,
            moduleType: activeDownload.moduleType,
            episodeNumber: activeDownload.episodeNumber,
            downloadDate: Date(),
            originalURL: activeDownload.originalURL,
            localURL: finalLocation,
            imageURL: activeDownload.imageURL,
            episodeID: activeDownload.episodeID,
            aniListID: nil // We need to store this in the ActiveDownload if available
        )
        
        // Add to saved episodes and persist
        savedEpisodes.append(newEpisode)
        saveEpisodes()
        
        // Log the file size
        if let fileSize = newEpisode.fileSize {
            let sizeMB = Double(fileSize) / (1024 * 1024)
            Logger.shared.log("Downloaded file size: \(String(format: "%.2f", sizeMB)) MB", type: "Download")
        }
        
        // Clean up the download task
        cleanupDownloadTask(assetDownloadTask)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Handle download completion or failure
        guard let assetDownloadTask = task as? AVAssetDownloadTask else { return }
        
        guard let downloadID = activeDownloadTasks[assetDownloadTask],
              let activeDownload = activeDownloads.first(where: { $0.id == downloadID }) else {
            
            if let error = error {
                let nsError = error as NSError
                Logger.shared.log("Download failed with unidentified task: Error \(nsError.code): \(nsError.localizedDescription)", type: "Error")
                
                // Log if it's specifically a 403 error
                if nsError.code == -1009 {
                    Logger.shared.log("Connection error detected. Possible connectivity issue.", type: "Error")
                } else if nsError.code == -1003 {
                    Logger.shared.log("Host not found error. DNS resolution failed.", type: "Error")
                } else if nsError.code == -1 || nsError.code == 403 {
                    Logger.shared.log("Error 403/Forbidden: Server rejected the request. This may be a header or authentication issue.", type: "Error")
                    Logger.shared.log("URL attempting to access: \(task.originalRequest?.url?.absoluteString ?? "unknown")", type: "Error")
                    
                    if let request = task.originalRequest, let headers = request.allHTTPHeaderFields {
                        Logger.shared.log("Headers used: \(headers)", type: "Error")
                    } else {
                        Logger.shared.log("No headers found in the request", type: "Error")
                    }
                }
            }
            return
        }
        
        if let error = error {
            // Get detailed error information
            let nsError = error as NSError
            let errorCode = nsError.code
            let errorDescription = nsError.localizedDescription
            
            // Log specific error information based on error code
            if errorCode == -1009 {
                Logger.shared.log("Download failed due to connectivity issue: \(activeDownload.title)", type: "Error")
            } else if errorCode == -1003 {
                Logger.shared.log("Download failed due to DNS resolution failure: \(activeDownload.title)", type: "Error")
            } else if errorCode == -1 || errorCode == 403 {
                Logger.shared.log("Download failed with 403 Forbidden error: \(activeDownload.title)", type: "Error")
                Logger.shared.log("This is likely due to missing or incorrect headers", type: "Error")
                
                // Log the URL and headers used
                Logger.shared.log("URL: \(activeDownload.originalURL.absoluteString)", type: "Error")
                if let request = task.originalRequest, let headers = request.allHTTPHeaderFields {
                    Logger.shared.log("Headers used: \(headers)", type: "Error")
                } else {
                    Logger.shared.log("No headers found in the request", type: "Error")
                }
                
                // Suggest potential fixes
                Logger.shared.log("Suggest checking if the server requires specific headers like Referer or Origin", type: "Error")
            } else {
                // Generic error message for other error codes
                Logger.shared.log("Download failed for \(activeDownload.title): \(errorDescription) (Error \(errorCode))", type: "Error")
            }
            
            // Clean up this failed download
            cleanupDownloadTask(task)
            
            // Process next download in queue if auto-start is enabled
            if autoStartDownloads {
                processNextQueuedDownload()
            }
        } else {
            Logger.shared.log("Download completed with no error, but episode was not saved: \(activeDownload.title)", type: "Warning")
            cleanupDownloadTask(task)
        }
    }
    
    func urlSession(_ session: URLSession,
                   assetDownloadTask: AVAssetDownloadTask,
                   didLoad timeRange: CMTimeRange,
                   totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                   timeRangeExpectedToLoad: CMTimeRange) {
        
        // Calculate progress
        let progress = loadedTimeRanges
            .map { $0.timeRangeValue.duration.seconds / timeRangeExpectedToLoad.duration.seconds }
            .reduce(0, +)
        
        // Update active download progress
        guard let downloadID = activeDownloadTasks[assetDownloadTask],
              let index = activeDownloads.firstIndex(where: { $0.id == downloadID }) else {
            return
        }
        
        DispatchQueue.main.async {
            var download = self.activeDownloads[index]
            download.progress = progress
            self.activeDownloads[index] = download
        }
    }
}
