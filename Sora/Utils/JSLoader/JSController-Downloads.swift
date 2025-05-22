//
//  JSController-Downloads.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import Foundation
import AVKit
import AVFoundation
import SwiftUI

/// Enumeration of different download notification types to enable selective UI updates
enum DownloadNotificationType: String {
    case progress = "downloadProgressChanged"           // Progress updates during download (no cache clearing needed)
    case statusChange = "downloadStatusChanged"         // Download started/queued/cancelled (no cache clearing needed)
    case completed = "downloadCompleted"                // Download finished (cache clearing needed)
    case deleted = "downloadDeleted"                    // Asset deleted (cache clearing needed)
    case libraryChange = "downloadLibraryChanged"       // Library updated (cache clearing needed)
    case cleanup = "downloadCleanup"                    // Cleanup operations (cache clearing needed)
}

// Extension for download functionality
extension JSController {
    
    // MARK: - Download Session Setup
    
    // Class-level property to track asset validation
    private static var hasValidatedAssets = false
    
    // MARK: - Progress Update Debouncing
    
    /// Tracks the last time a progress notification was sent for each download
    private static var lastProgressUpdateTime: [UUID: Date] = [:]
    
    /// Minimum time interval between progress notifications (in seconds)
    private static let progressUpdateInterval: TimeInterval = 0.5 // Max 2 updates per second
    
    /// Pending progress updates to batch and send
    private static var pendingProgressUpdates: [UUID: (progress: Double, episodeNumber: Int?)] = [:]
    
    /// Timer for batched progress updates
    private static var progressUpdateTimer: Timer?
    
    func initializeDownloadSession() {
        // Create a unique identifier for the background session
        let sessionIdentifier = "hls-downloader-\(UUID().uuidString)"
        
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        
        // Configure session
        configuration.allowsCellularAccess = true
        configuration.shouldUseExtendedBackgroundIdleMode = true
        configuration.waitsForConnectivity = true
        
        // Create session with configuration
        downloadURLSession = AVAssetDownloadURLSession(
            configuration: configuration,
            assetDownloadDelegate: self,
            delegateQueue: .main
        )
        
        print("Download session initialized with ID: \(sessionIdentifier)")
        loadSavedAssets()
    }
    
    /// Sets up JavaScript download function if needed
    func setupDownloadFunction() {
        // No JavaScript-side setup needed for now
        print("Download function setup completed")
    }
    
    /// Helper function to post download notifications with proper naming
    private func postDownloadNotification(_ type: DownloadNotificationType, userInfo: [String: Any]? = nil) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name(type.rawValue),
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    // MARK: - Download Queue Management
    
    /// Initiates a download for the specified URL with the given headers
    /// - Parameters:
    ///   - url: The URL to download
    ///   - headers: HTTP headers to use for the request
    ///   - title: Optional title for the download (defaults to filename)
    ///   - imageURL: Optional image URL for the download
    ///   - isEpisode: Indicates if the download is for an episode
    ///   - showTitle: Optional show title for the episode (anime title)
    ///   - season: Optional season number for the episode
    ///   - episode: Optional episode number for the episode
    ///   - subtitleURL: Optional subtitle URL to download after video
    ///   - module: Optional module to determine streamType
    ///   - completionHandler: Optional callback for download status
    func startDownload(
        url: URL,
        headers: [String: String] = [:],
        title: String? = nil,
        imageURL: URL? = nil,
        isEpisode: Bool = false,
        showTitle: String? = nil,
        season: Int? = nil,
        episode: Int? = nil,
        subtitleURL: URL? = nil,
        showPosterURL: URL? = nil,
        module: ScrapingModule? = nil,
        completionHandler: ((Bool, String) -> Void)? = nil
    ) {
        // If a module is provided, use the stream type aware download
        if let module = module {
            // Use the stream type aware download method
            downloadWithStreamTypeSupport(
                url: url,
                headers: headers,
                title: title,
                imageURL: imageURL,
                module: module,
                isEpisode: isEpisode,
                showTitle: showTitle,
                season: season,
                episode: episode,
                subtitleURL: subtitleURL,
                showPosterURL: showPosterURL,
                completionHandler: completionHandler
            )
            return
        }
        
        // Legacy path for downloads without a module - use AVAssetDownloadURLSession
        // Create an asset with custom HTTP header fields for authorization
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        
        let downloadTitle = title ?? url.lastPathComponent
        
        // Ensure we have a proper anime title for episodes
        let animeTitle = isEpisode ? (showTitle ?? "Unknown Anime") : nil
        
        // Create metadata for the download with proper anime title
        let downloadType: DownloadType = isEpisode ? .episode : .movie
        let assetMetadata = AssetMetadata(
            title: downloadTitle,
            overview: nil,
            posterURL: imageURL, // Episode thumbnail
            backdropURL: imageURL,
            releaseDate: nil,
            showTitle: animeTitle,
            season: season,
            episode: episode,
            showPosterURL: showPosterURL // Main show poster
        )
        
        // Create the download ID now so we can use it for notifications
        let downloadID = UUID()
        
        // Create a download object with queued status
        let download = JSActiveDownload(
            id: downloadID,
            originalURL: url,
            progress: 0,
            task: nil,  // Task will be created when the download starts
            queueStatus: .queued,
            type: downloadType,
            metadata: assetMetadata,
            title: downloadTitle,
            imageURL: imageURL,
            subtitleURL: subtitleURL,
            asset: asset,
            headers: headers
        )
        
        // Add to the download queue
        downloadQueue.append(download)
        
        // Immediately notify users about queued download
        postDownloadNotification(.statusChange)
        
        // If this is an episode, also post a progress update to force UI refresh with queued status
        if let episodeNumber = download.metadata?.episode {
            postDownloadNotification(.progress, userInfo: [
                "episodeNumber": episodeNumber,
                "progress": 0.0,
                "status": "queued"
            ])
        }
        
        // Inform caller of success
        completionHandler?(true, "Download queued")
        
        // Process the queue if we're not already doing so
        if !isProcessingQueue {
            processDownloadQueue()
        }
    }
    
    /// Process the download queue and start downloads as slots are available
    private func processDownloadQueue() {
        // Set flag to prevent multiple concurrent processing
        isProcessingQueue = true
        
        // Calculate how many more downloads we can start
        let activeCount = activeDownloads.count
        let slotsAvailable = max(0, maxConcurrentDownloads - activeCount)
        
        if slotsAvailable > 0 && !downloadQueue.isEmpty {
            // Get the next batch of downloads to start (up to available slots)
            let nextBatch = Array(downloadQueue.prefix(slotsAvailable))
            
            // Remove these from the queue
            downloadQueue.removeFirst(min(slotsAvailable, downloadQueue.count))
            
            // Start each download
            for queuedDownload in nextBatch {
                startQueuedDownload(queuedDownload)
            }
        }
        
        // If we still have queued downloads, schedule another check
        if !downloadQueue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.processDownloadQueue()
            }
        } else {
            // No more queued downloads
            isProcessingQueue = false
        }
    }
    
    /// Start a previously queued download
    private func startQueuedDownload(_ queuedDownload: JSActiveDownload) {
        guard let asset = queuedDownload.asset else {
            print("Missing asset for queued download")
            return
        }
        
        // Create the download task
        guard let task = downloadURLSession?.makeAssetDownloadTask(
            asset: asset,
            assetTitle: queuedDownload.title ?? queuedDownload.originalURL.lastPathComponent,
            assetArtworkData: nil,
            options: nil
        ) else {
            print("Failed to create download task for queued download")
            return
        }
        
        // Create a new download object with the task
        let download = JSActiveDownload(
            id: queuedDownload.id,
            originalURL: queuedDownload.originalURL,
            progress: 0,
            task: task,
            queueStatus: .downloading,
            type: queuedDownload.type,
            metadata: queuedDownload.metadata,
            title: queuedDownload.title,
            imageURL: queuedDownload.imageURL,
            subtitleURL: queuedDownload.subtitleURL
        )
        
        // Add to active downloads
        activeDownloads.append(download)
        activeDownloadMap[task] = download.id
        
        // Start the download
        task.resume()
        print("Queued download started: \(download.title ?? download.originalURL.lastPathComponent)")
        
        // Save the download state
        saveDownloadState()
        
        // Update UI to show download has started
        postDownloadNotification(.statusChange)
        
        // If this is an episode, also post a progress update to force UI refresh
        if let episodeNumber = download.metadata?.episode {
            postDownloadNotification(.progress, userInfo: [
                "episodeNumber": episodeNumber,
                "progress": 0.0,
                "status": "downloading"
            ])
        }
    }
    
    /// Clean up a download task when it's completed or failed
    private func cleanupDownloadTask(_ task: URLSessionTask) {
        guard let downloadID = activeDownloadMap[task] else { return }
        
        activeDownloads.removeAll { $0.id == downloadID }
        activeDownloadMap.removeValue(forKey: task)
        saveDownloadState()
        
        print("Cleaned up download task")
        
        // Start processing the queue again if we have pending downloads
        if !downloadQueue.isEmpty && !isProcessingQueue {
            processDownloadQueue()
        }
    }
    
    /// Update download progress
    func updateDownloadProgress(task: AVAssetDownloadTask, progress: Double) {
        guard let downloadID = activeDownloadMap[task] else { return }
        
        // Clamp progress between 0 and 1
        let finalProgress = min(max(progress, 0.0), 1.0)
        
        // Find and update the download progress
        if let downloadIndex = activeDownloads.firstIndex(where: { $0.id == downloadID }) {
            let download = activeDownloads[downloadIndex]
            let previousProgress = download.progress
            activeDownloads[downloadIndex].progress = finalProgress
            
            // Send notifications for progress updates to ensure smooth real-time updates
            // Send notification if:
            // 1. Progress increased by at least 0.5% (0.005) for very smooth updates
            // 2. Download completed (reached 100%)
            // 3. This is the first progress update (from 0)
            // 4. It's been a significant change (covers edge cases)
            let progressDifference = finalProgress - previousProgress
            let shouldUpdate = progressDifference >= 0.005 || finalProgress >= 1.0 || previousProgress == 0.0
            
            if shouldUpdate {
                // Post progress update notification (no cache clearing needed for progress updates)
                postDownloadNotification(.progress)
                
                // Also post detailed progress update with episode number if it's an episode
                if let episodeNumber = download.metadata?.episode {
                    let status = finalProgress >= 1.0 ? "completed" : "downloading"
                    postDownloadNotification(.progress, userInfo: [
                        "episodeNumber": episodeNumber,
                        "progress": finalProgress,
                        "status": status
                    ])
                }
            }
        }
    }
    
    /// Downloads a subtitle file and associates it with an asset
    /// - Parameters:
    ///   - subtitleURL: The URL of the subtitle file to download
    ///   - assetID: The ID of the asset this subtitle is associated with
    func downloadSubtitle(subtitleURL: URL, assetID: String) {
        print("Downloading subtitle from: \(subtitleURL.absoluteString) for asset ID: \(assetID)")
        
        let session = URLSession.shared
        var request = URLRequest(url: subtitleURL)
        
        // Add more comprehensive headers for subtitle downloads
        request.addValue("*/*", forHTTPHeaderField: "Accept")
        request.addValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.addValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        
        // Extract domain from subtitle URL to use as referer
        if let host = subtitleURL.host {
            let referer = "https://\(host)/"
            request.addValue(referer, forHTTPHeaderField: "Referer")
            request.addValue(referer, forHTTPHeaderField: "Origin")
        }
        
        print("Subtitle download request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        // Create a task to download the subtitle file
        let task = session.downloadTask(with: request) { [weak self] (tempURL, response, error) in
            guard let self = self else {
                print("Self reference lost during subtitle download")
                return
            }
            
            if let error = error {
                print("Subtitle download error: \(error.localizedDescription)")
                return
            }
            
            guard let tempURL = tempURL else {
                print("No temporary URL received for subtitle download")
                return
            }
            
            guard let downloadDir = self.getPersistentDownloadDirectory() else {
                print("Failed to get persistent download directory for subtitle")
                return
            }
            
            // Log response details for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("Subtitle download HTTP status: \(httpResponse.statusCode)")
                print("Subtitle download content type: \(httpResponse.mimeType ?? "unknown")")
            }
            
            // Try to read content to validate it's actually a subtitle file
            do {
                let subtitleData = try Data(contentsOf: tempURL)
                let subtitleContent = String(data: subtitleData, encoding: .utf8) ?? ""
                
                if subtitleContent.isEmpty {
                    print("Warning: Subtitle file appears to be empty")
                } else {
                    print("Subtitle file contains \(subtitleData.count) bytes of data")
                    if subtitleContent.hasPrefix("WEBVTT") {
                        print("Valid WebVTT subtitle detected")
                    } else if subtitleContent.contains(" --> ") {
                        print("Subtitle file contains timing markers")
                    } else {
                        print("Warning: Subtitle content doesn't appear to be in a recognized format")
                    }
                }
            } catch {
                print("Error reading subtitle content for validation: \(error.localizedDescription)")
            }
            
            // Determine file extension based on the content type or URL
            let fileExtension: String
            if let mimeType = response?.mimeType {
                switch mimeType.lowercased() {
                case "text/vtt", "text/webvtt":
                    fileExtension = "vtt"
                case "text/srt", "application/x-subrip":
                    fileExtension = "srt"
                default:
                    // Use original extension or default to vtt
                    fileExtension = subtitleURL.pathExtension.isEmpty ? "vtt" : subtitleURL.pathExtension
                }
            } else {
                fileExtension = subtitleURL.pathExtension.isEmpty ? "vtt" : subtitleURL.pathExtension
            }
            
            // Create a filename for the subtitle using the asset ID
            let localFilename = "subtitle-\(assetID).\(fileExtension)"
            let localURL = downloadDir.appendingPathComponent(localFilename)
            
            do {
                // If file already exists, remove it
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                    print("Removed existing subtitle file at \(localURL.path)")
                }
                
                // Move the downloaded file to the persistent location
                try FileManager.default.moveItem(at: tempURL, to: localURL)
                
                // Update the asset with the subtitle URL
                self.updateAssetWithSubtitle(assetID: assetID, 
                                         subtitleURL: subtitleURL, 
                                         localSubtitleURL: localURL)
                
                print("Subtitle downloaded successfully: \(localURL.path)")
                
                // Show success notification
                DispatchQueue.main.async {
                    DropManager.shared.success("Subtitle downloaded successfully")
                    
                    // Force a UI update for the episode cell
                    NotificationCenter.default.post(
                        name: NSNotification.Name("downloadStatusChanged"),
                        object: nil
                    )
                    
                    // If this is an episode, also post a progress update to force UI refresh
                    if let asset = self.savedAssets.first(where: { $0.id.uuidString == assetID }),
                       let episodeNumber = asset.metadata?.episode {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("downloadProgressUpdated"),
                            object: nil,
                            userInfo: [
                                "episodeNumber": episodeNumber,
                                "progress": 1.0
                            ]
                        )
                    }
                }
            } catch {
                print("Error moving subtitle file: \(error.localizedDescription)")
            }
        }
        
        task.resume()
        print("Subtitle download task started")
    }
    
    /// Updates an asset with subtitle information after subtitle download completes
    /// - Parameters:
    ///   - assetID: The ID of the asset to update
    ///   - subtitleURL: The original subtitle URL
    ///   - localSubtitleURL: The local path where the subtitle file is stored
    private func updateAssetWithSubtitle(assetID: String, subtitleURL: URL, localSubtitleURL: URL) {
        // Find the asset in the saved assets array
        if let index = savedAssets.firstIndex(where: { $0.id.uuidString == assetID }) {
            // Create a new asset with the subtitle info (since struct is immutable)
            let existingAsset = savedAssets[index]
            let updatedAsset = DownloadedAsset(
                id: existingAsset.id,
                name: existingAsset.name,
                downloadDate: existingAsset.downloadDate,
                originalURL: existingAsset.originalURL,
                localURL: existingAsset.localURL,
                type: existingAsset.type,
                metadata: existingAsset.metadata,
                subtitleURL: subtitleURL,
                localSubtitleURL: localSubtitleURL
            )
            
            // Dispatch the UI update to the main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Replace the old asset with the updated one
                self.savedAssets[index] = updatedAsset
                
                // Save the updated assets array
                self.saveAssets()
            }
        }
    }
    
    // MARK: - Asset Management
    
    /// Load saved assets from UserDefaults
    func loadSavedAssets() {
        // First, migrate any existing files from Documents to Application Support
        migrateExistingFilesToPersistentStorage()
        
        guard let data = UserDefaults.standard.data(forKey: "downloadedAssets") else { 
            print("No saved assets found")
            JSController.hasValidatedAssets = true // Mark as validated since there's nothing to validate
            return 
        }
        
        do {
            savedAssets = try JSONDecoder().decode([DownloadedAsset].self, from: data)
            print("Loaded \(savedAssets.count) saved assets")
            
            // Only validate once per app session to avoid excessive file checks
            if !JSController.hasValidatedAssets {
                print("Validating asset locations...")
                validateAndUpdateAssetLocations()
                JSController.hasValidatedAssets = true
            }
        } catch {
            print("Error loading saved assets: \(error.localizedDescription)")
        }
    }
    
    /// Migrates any existing .movpkg files from Documents directory to the persistent location
    private func migrateExistingFilesToPersistentStorage() {
        let fileManager = FileManager.default
        
        // Get Documents and Application Support directories
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
              let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        
        // Create persistent downloads directory if it doesn't exist
        let persistentDir = appSupportDir.appendingPathComponent("SoraDownloads", isDirectory: true)
        do {
            if !fileManager.fileExists(atPath: persistentDir.path) {
                try fileManager.createDirectory(at: persistentDir, withIntermediateDirectories: true)
                print("Created persistent download directory at \(persistentDir.path)")
            }
            
            // Find any .movpkg files in the Documents directory
            let files = try fileManager.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil)
            let movpkgFiles = files.filter { $0.pathExtension == "movpkg" }
            
            if !movpkgFiles.isEmpty {
                print("Found \(movpkgFiles.count) .movpkg files in Documents directory to migrate")
                
                // Migrate each file
                for fileURL in movpkgFiles {
                    let filename = fileURL.lastPathComponent
                    let destinationURL = persistentDir.appendingPathComponent(filename)
                    
                    // Check if file already exists in destination
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        // Generate a unique name to avoid conflicts
                        let uniqueID = UUID().uuidString
                        let newDestinationURL = persistentDir.appendingPathComponent("\(filename)-\(uniqueID)")
                        try fileManager.copyItem(at: fileURL, to: newDestinationURL)
                        print("Migrated file with unique name: \(filename) → \(newDestinationURL.lastPathComponent)")
                    } else {
                        // Move the file to the persistent directory
                        try fileManager.copyItem(at: fileURL, to: destinationURL)
                        print("Migrated file: \(filename)")
                    }
                }
            } else {
                print("No .movpkg files found in Documents directory for migration")
            }
        } catch {
            print("Error during migration: \(error.localizedDescription)")
        }
    }
    
    /// Validates that saved assets exist and updates their locations if needed
    private func validateAndUpdateAssetLocations() {
        let fileManager = FileManager.default
        var updatedAssets = false
        var assetsToRemove: [UUID] = []
        
        // Check each asset and update its location if needed
        for (index, asset) in savedAssets.enumerated() {
            // Check if the file exists at the stored path
            if !fileManager.fileExists(atPath: asset.localURL.path) {
                print("Asset file not found at saved path: \(asset.localURL.path)")
                
                // Try to find the file in the persistent directory
                if let persistentURL = findAssetInPersistentStorage(assetName: asset.name) {
                    // Update the asset with the new URL
                    print("Found asset in persistent storage: \(persistentURL.path)")
                    savedAssets[index] = DownloadedAsset(
                        id: asset.id,
                        name: asset.name,
                        downloadDate: asset.downloadDate,
                        originalURL: asset.originalURL,
                        localURL: persistentURL,
                        type: asset.type,
                        metadata: asset.metadata,
                        subtitleURL: asset.subtitleURL,
                        localSubtitleURL: asset.localSubtitleURL
                    )
                    updatedAssets = true
                } else {
                    // If we can't find the file, mark it for removal
                    print("Asset not found in persistent storage. Marking for removal: \(asset.name)")
                    assetsToRemove.append(asset.id)
                    updatedAssets = true
                }
            }
        }
        
        // Remove assets that don't exist anymore
        if !assetsToRemove.isEmpty {
            let countBefore = savedAssets.count
            savedAssets.removeAll { assetsToRemove.contains($0.id) }
            print("Removed \(countBefore - savedAssets.count) missing assets from the library")
            
            // Notify observers of the change (library cleanup requires cache clearing)
            postDownloadNotification(.cleanup)
        }
        
        // Save the updated asset information if changes were made
        if updatedAssets {
            saveAssets()
        }
    }
    
    /// Attempts to find an asset in the persistent storage directory
    /// - Parameter assetName: The name of the asset to find
    /// - Returns: URL to the found asset or nil if not found
    private func findAssetInPersistentStorage(assetName: String) -> URL? {
        let fileManager = FileManager.default
        
        // Get Application Support directory
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // Path to our downloads directory
        let downloadDir = appSupportDir.appendingPathComponent("SoraDownloads", isDirectory: true)
        
        // Check if directory exists
        guard fileManager.fileExists(atPath: downloadDir.path) else {
            return nil
        }
        
        do {
            // Get all files in the directory
            let files = try fileManager.contentsOfDirectory(at: downloadDir, includingPropertiesForKeys: nil)
            
            // Try to find a file that contains the asset name
            for file in files where file.pathExtension == "movpkg" {
                let filename = file.lastPathComponent
                
                // If the filename contains the asset name, it's likely our file
                if filename.contains(assetName) || assetName.contains(filename.components(separatedBy: "-").first ?? "") {
                    return file
                }
            }
        } catch {
            print("Error searching for asset in persistent storage: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Save assets to UserDefaults
    func saveAssets() {
        do {
            let data = try JSONEncoder().encode(savedAssets)
            UserDefaults.standard.set(data, forKey: "downloadedAssets")
            print("Saved \(savedAssets.count) assets to UserDefaults")
        } catch {
            print("Error saving assets: \(error.localizedDescription)")
        }
    }
    
    /// Save the current state of downloads
    private func saveDownloadState() {
        // Only metadata needs to be saved since the tasks themselves can't be serialized
        let downloadInfo = activeDownloads.map { download -> [String: Any] in
            return [
                "id": download.id.uuidString,
                "url": download.originalURL.absoluteString,
                "type": download.type.rawValue,
                "title": download.title ?? download.originalURL.lastPathComponent
            ]
        }
        
        UserDefaults.standard.set(downloadInfo, forKey: "activeDownloads")
        print("Saved download state with \(downloadInfo.count) active downloads")
    }
    
    /// Delete an asset
    func deleteAsset(_ asset: DownloadedAsset) {
        do {
            // Check if file exists before attempting to delete
            if FileManager.default.fileExists(atPath: asset.localURL.path) {
                try FileManager.default.removeItem(at: asset.localURL)
                print("Deleted asset file: \(asset.localURL.path)")
            } else {
                print("Asset file not found at path: \(asset.localURL.path)")
            }
            
            // Remove from saved assets regardless of whether file was found
            savedAssets.removeAll { $0.id == asset.id }
            saveAssets()
            print("Removed asset from library: \(asset.name)")
            
            // Notify observers that an asset was deleted (cache clearing needed)
            postDownloadNotification(.deleted)
        } catch {
            print("Error deleting asset: \(error.localizedDescription)")
        }
    }
    
    /// Remove an asset from the library without deleting the file
    func removeAssetFromLibrary(_ asset: DownloadedAsset) {
        // Only remove the entry from savedAssets
        savedAssets.removeAll { $0.id == asset.id }
        saveAssets()
        print("Removed asset from library (file preserved): \(asset.name)")
        
        // Notify observers that the library changed (cache clearing needed)
        postDownloadNotification(.libraryChange)
    }
    
    /// Returns the directory for persistent downloads
    func getPersistentDownloadDirectory() -> URL? {
        let fileManager = FileManager.default
        
        // Get Application Support directory
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("Cannot access Application Support directory")
            return nil
        }
        
        // Create a dedicated subdirectory for our downloads if it doesn't exist
        let downloadDir = appSupportDir.appendingPathComponent("SoraDownloads", isDirectory: true)
        
        do {
            if !fileManager.fileExists(atPath: downloadDir.path) {
                try fileManager.createDirectory(at: downloadDir, withIntermediateDirectories: true)
                print("Created persistent download directory at \(downloadDir.path)")
            }
            return downloadDir
        } catch {
            print("Error creating download directory: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Checks if an asset file exists before attempting to play it
    /// - Parameter asset: The asset to verify
    /// - Returns: True if the file exists, false otherwise
    func verifyAssetFileExists(_ asset: DownloadedAsset) -> Bool {
        let fileExists = FileManager.default.fileExists(atPath: asset.localURL.path)
        
        if !fileExists {
            // Try to find the file in a different location
            if let newLocation = findAssetInPersistentStorage(assetName: asset.name) {
                // Update the asset with the new location
                if let index = savedAssets.firstIndex(where: { $0.id == asset.id }) {
                    savedAssets[index] = DownloadedAsset(
                        id: asset.id,
                        name: asset.name, 
                        downloadDate: asset.downloadDate,
                        originalURL: asset.originalURL,
                        localURL: newLocation,
                        type: asset.type,
                        metadata: asset.metadata,
                        subtitleURL: asset.subtitleURL,
                        localSubtitleURL: asset.localSubtitleURL
                    )
                    saveAssets()
                    return true
                }
            } else {
                // File is truly missing - remove it from saved assets
                savedAssets.removeAll { $0.id == asset.id }
                saveAssets()
                
                // Show an error to the user
                DispatchQueue.main.async {
                    DropManager.shared.error("File not found: \(asset.name)")
                }
            }
        }
        
        return fileExists
    }
    
    /// Determines if a new download will start immediately or be queued
    /// - Returns: true if the download will start immediately, false if it will be queued
    func willDownloadStartImmediately() -> Bool {
        let activeCount = activeDownloads.count
        let slotsAvailable = max(0, maxConcurrentDownloads - activeCount)
        return slotsAvailable > 0
    }
    
    /// Checks if an episode is already downloaded or currently being downloaded
    /// - Parameters:
    ///   - showTitle: The title of the show (anime title)
    ///   - episodeNumber: The episode number
    ///   - season: The season number (defaults to 1)
    /// - Returns: Download status indicating if the episode is downloaded, being downloaded, or not downloaded
    func isEpisodeDownloadedOrInProgress(
        showTitle: String,
        episodeNumber: Int,
        season: Int = 1
    ) -> EpisodeDownloadStatus {
        // First check if it's already downloaded
        for asset in savedAssets {
            // Skip if not an episode or show title doesn't match
            if asset.type != .episode { continue }
            guard let metadata = asset.metadata, 
                  let assetShowTitle = metadata.showTitle, 
                  assetShowTitle.caseInsensitiveCompare(showTitle) == .orderedSame else { 
                continue 
            }
            
            // Check episode number
            let assetEpisode = metadata.episode ?? 0
            let assetSeason = metadata.season ?? 1
            
            if assetEpisode == episodeNumber && assetSeason == season {
                return .downloaded(asset)
            }
        }
        
        // Then check if it's currently being downloaded (actively downloading)
        for download in activeDownloads {
            // Skip if not an episode or show title doesn't match
            if download.type != .episode { continue }
            guard let metadata = download.metadata, 
                  let assetShowTitle = metadata.showTitle, 
                  assetShowTitle.caseInsensitiveCompare(showTitle) == .orderedSame else { 
                continue 
            }
            
            // Check episode number
            let assetEpisode = metadata.episode ?? 0
            let assetSeason = metadata.season ?? 1
            
            if assetEpisode == episodeNumber && assetSeason == season {
                return .downloading(download)
            }
        }
        
        // Finally check if it's queued for download
        for download in downloadQueue {
            // Skip if not an episode or show title doesn't match
            if download.type != .episode { continue }
            guard let metadata = download.metadata, 
                  let assetShowTitle = metadata.showTitle, 
                  assetShowTitle.caseInsensitiveCompare(showTitle) == .orderedSame else { 
                continue 
            }
            
            // Check episode number
            let assetEpisode = metadata.episode ?? 0
            let assetSeason = metadata.season ?? 1
            
            if assetEpisode == episodeNumber && assetSeason == season {
                return .downloading(download)
            }
        }
        
        // Not downloaded or being downloaded
        return .notDownloaded
    }
    
    /// Cancel a queued download that hasn't started yet
    func cancelQueuedDownload(_ downloadID: UUID) {
        // Remove from the download queue if it exists there
        if let index = downloadQueue.firstIndex(where: { $0.id == downloadID }) {
            let downloadTitle = downloadQueue[index].title ?? downloadQueue[index].originalURL.lastPathComponent
            downloadQueue.remove(at: index)
            
            // Show notification
            DropManager.shared.info("Download cancelled: \(downloadTitle)")
            
            // Notify observers of status change (no cache clearing needed for cancellation)
            postDownloadNotification(.statusChange)
            
            print("Cancelled queued download: \(downloadTitle)")
        }
    }
}

// MARK: - AVAssetDownloadDelegate
extension JSController: AVAssetDownloadDelegate {
    
    /// Called when a download task finishes downloading the asset
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard let downloadID = activeDownloadMap[assetDownloadTask],
              let downloadIndex = activeDownloads.firstIndex(where: { $0.id == downloadID }) else {
            print("Download task finished but couldn't find associated download")
            return
        }
        
        let download = activeDownloads[downloadIndex]

        // Move the downloaded file to Application Support directory for persistence
        guard let persistentURL = moveToApplicationSupportDirectory(from: location, filename: download.title ?? download.originalURL.lastPathComponent) else {
            print("Failed to move downloaded file to persistent storage")
            return
        }
        
        // Create a new DownloadedAsset with metadata from the active download
        let newAsset = DownloadedAsset(
            name: download.title ?? download.originalURL.lastPathComponent,
            downloadDate: Date(),
            originalURL: download.originalURL,
            localURL: persistentURL,
            type: download.type,
            metadata: download.metadata,  // Use the metadata we created when starting the download
            subtitleURL: download.subtitleURL // Store the subtitle URL, but localSubtitleURL will be nil until subtitle is downloaded
        )
        
        // Add to saved assets and save
        savedAssets.append(newAsset)
        saveAssets()
        
        // If there's a subtitle URL, download it now that the video is saved
        if let subtitleURL = download.subtitleURL {
            downloadSubtitle(subtitleURL: subtitleURL, assetID: newAsset.id.uuidString)
        } else {
            // No subtitle URL, so we can consider the download complete
            // Notify that download completed (cache clearing needed for new file)
            postDownloadNotification(.completed)
            
            // If this is an episode, also post a progress update to force UI refresh
            if let episodeNumber = download.metadata?.episode {
                postDownloadNotification(.progress, userInfo: [
                    "episodeNumber": episodeNumber,
                    "progress": 1.0,
                    "status": "completed"
                ])
            }
        }
        
        // Clean up the download task
        cleanupDownloadTask(assetDownloadTask)
        
        print("Download completed and moved to persistent storage: \(newAsset.name)")
    }
    
    /// Moves a downloaded file to Application Support directory to preserve it across app updates
    /// - Parameters:
    ///   - location: The original location from the download task
    ///   - filename: Name to use for the file
    /// - Returns: URL to the new persistent location or nil if move failed
    private func moveToApplicationSupportDirectory(from location: URL, filename: String) -> URL? {
        let fileManager = FileManager.default
        
        // Get Application Support directory 
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("Cannot access Application Support directory")
            return nil
        }
        
        // Create a dedicated subdirectory for our downloads if it doesn't exist
        let downloadDir = appSupportDir.appendingPathComponent("SoraDownloads", isDirectory: true)
        
        do {
            if !fileManager.fileExists(atPath: downloadDir.path) {
                try fileManager.createDirectory(at: downloadDir, withIntermediateDirectories: true)
                print("Created persistent download directory at \(downloadDir.path)")
            }
            
            // Generate unique filename with UUID to avoid conflicts
            let uniqueID = UUID().uuidString
            let safeFilename = filename.replacingOccurrences(of: "/", with: "-")
                                      .replacingOccurrences(of: ":", with: "-")
            
            let destinationURL = downloadDir.appendingPathComponent("\(safeFilename)-\(uniqueID).movpkg")
            
            // Move the file to the persistent location
            try fileManager.moveItem(at: location, to: destinationURL)
            print("Successfully moved download to persistent storage: \(destinationURL.path)")
            
            return destinationURL
        } catch {
            print("Error moving download to persistent storage: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Called when a download task encounters an error
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Enhanced error logging
            print("Download error: \(error.localizedDescription)")
            
            // Extract and log the underlying error details
            let nsError = error as NSError
            print("Error domain: \(nsError.domain), code: \(nsError.code)")
            
            if let underlyingError = nsError.userInfo["NSUnderlyingError"] as? NSError {
                print("Underlying error: \(underlyingError)")
            }
            
            for (key, value) in nsError.userInfo {
                print("Error info - \(key): \(value)")
            }
            
            // Check if there's a system network error 
            if let urlError = error as? URLError {
                print("URLError code: \(urlError.code.rawValue)")
                
                if urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                    print("Network error: \(urlError.localizedDescription)")
                    
                    DispatchQueue.main.async {
                        DropManager.shared.error("Network error: \(urlError.localizedDescription)")
                    }
                } else if urlError.code == .userAuthenticationRequired || urlError.code == .userCancelledAuthentication {
                    print("Authentication error: \(urlError.localizedDescription)")
                    
                    DispatchQueue.main.async {
                        DropManager.shared.error("Authentication error: Check headers")
                    }
                }
            } else if error.localizedDescription.contains("403") {
                // Specific handling for 403 Forbidden errors
                print("403 Forbidden error - Server rejected the request")
                
                DispatchQueue.main.async {
                    DropManager.shared.error("Access denied (403): The server refused access to this content")
                }
            } else {
                DispatchQueue.main.async {
                    DropManager.shared.error("Download failed: \(error.localizedDescription)")
                }
            }
        }
        
        cleanupDownloadTask(task)
    }
    
    /// Update progress of download task
    func urlSession(_ session: URLSession,
                    assetDownloadTask: AVAssetDownloadTask,
                    didLoad timeRange: CMTimeRange,
                    totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                    timeRangeExpectedToLoad: CMTimeRange) {
        
        // Do a quick check to see if task is still registered
        guard let downloadID = activeDownloadMap[assetDownloadTask] else {
            print("Received progress for unknown download task")
            return
        }
        
        // Calculate download progress
        var totalProgress: Double = 0
        
        // Calculate the total progress by summing all loaded time ranges and dividing by expected time range
        for value in loadedTimeRanges {
            let loadedTimeRange = value.timeRangeValue
            let duration = loadedTimeRange.duration.seconds
            let expectedDuration = timeRangeExpectedToLoad.duration.seconds
            
            // Only add if the expected duration is valid (greater than 0)
            if expectedDuration > 0 {
                totalProgress += (duration / expectedDuration)
            }
        }
        
        // Clamp total progress between 0 and 1
        let finalProgress = min(max(totalProgress, 0.0), 1.0)
        
        // Update the download object with the new progress
        updateDownloadProgress(task: assetDownloadTask, progress: finalProgress)
    }
}

// MARK: - URLSessionTaskDelegate
extension JSController: URLSessionTaskDelegate {
    /// Called when a redirect is received
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Log information about the redirect
        print("==== REDIRECT DETECTED ====")
        print("Redirecting to: \(request.url?.absoluteString ?? "unknown")")
        print("Redirect status code: \(response.statusCode)")
        
        // Don't try to access originalRequest for AVAssetDownloadTask
        if !(task is AVAssetDownloadTask), let originalRequest = task.originalRequest {
            print("Original URL: \(originalRequest.url?.absoluteString ?? "unknown")")
            print("Original Headers: \(originalRequest.allHTTPHeaderFields ?? [:])")
            
            // Create a modified request that preserves ALL original headers
            var modifiedRequest = request
            
            // Add all original headers to the new request
            for (key, value) in originalRequest.allHTTPHeaderFields ?? [:] {
                // Only add if not already present in the redirect request
                if modifiedRequest.value(forHTTPHeaderField: key) == nil {
                    print("Adding missing header: \(key): \(value)")
                    modifiedRequest.addValue(value, forHTTPHeaderField: key)
                }
            }
            
            print("Final redirect headers: \(modifiedRequest.allHTTPHeaderFields ?? [:])")
            
            // Allow the redirect with our modified request
            completionHandler(modifiedRequest)
        } else {
            // For AVAssetDownloadTask, just accept the redirect as is
            print("Accepting redirect for AVAssetDownloadTask without header modification")
            completionHandler(request)
        }
    }
    
    /// Handle authentication challenges
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("==== AUTH CHALLENGE ====")
        print("Authentication method: \(challenge.protectionSpace.authenticationMethod)")
        print("Host: \(challenge.protectionSpace.host)")
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            // Handle SSL/TLS certificate validation
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                print("Accepting server trust for host: \(challenge.protectionSpace.host)")
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        // Default to performing authentication without credentials
        print("Using default handling for authentication challenge")
        completionHandler(.performDefaultHandling, nil)
    }
}

// MARK: - Download Types
/// Struct to represent an active download in JSController
struct JSActiveDownload: Identifiable, Equatable {
    let id: UUID
    let originalURL: URL
    var progress: Double
    let task: AVAssetDownloadTask?
    let type: DownloadType
    var metadata: AssetMetadata?
    var title: String?
    var imageURL: URL?
    var subtitleURL: URL?
    var queueStatus: DownloadQueueStatus
    var asset: AVURLAsset?
    var headers: [String: String]
    
    // Implement Equatable
    static func == (lhs: JSActiveDownload, rhs: JSActiveDownload) -> Bool {
        return lhs.id == rhs.id &&
               lhs.originalURL == rhs.originalURL &&
               lhs.progress == rhs.progress &&
               lhs.type == rhs.type &&
               lhs.title == rhs.title &&
               lhs.imageURL == rhs.imageURL &&
               lhs.subtitleURL == rhs.subtitleURL &&
               lhs.queueStatus == rhs.queueStatus
    }
    
    init(
        id: UUID = UUID(),
        originalURL: URL,
        progress: Double = 0,
        task: AVAssetDownloadTask? = nil,
        queueStatus: DownloadQueueStatus = .queued,
        type: DownloadType = .movie,
        metadata: AssetMetadata? = nil,
        title: String? = nil,
        imageURL: URL? = nil,
        subtitleURL: URL? = nil,
        asset: AVURLAsset? = nil,
        headers: [String: String] = [:]
    ) {
        self.id = id
        self.originalURL = originalURL
        self.progress = progress
        self.task = task
        self.type = type
        self.metadata = metadata
        self.title = title
        self.imageURL = imageURL
        self.subtitleURL = subtitleURL
        self.queueStatus = queueStatus
        self.asset = asset
        self.headers = headers
    }
}

/// Represents the download status of an episode
enum EpisodeDownloadStatus: Equatable {
    /// Episode is not downloaded and not being downloaded
    case notDownloaded
    /// Episode is currently being downloaded
    case downloading(JSActiveDownload)
    /// Episode is already downloaded
    case downloaded(DownloadedAsset)
    
    /// Returns true if the episode is either downloaded or being downloaded
    var isDownloadedOrInProgress: Bool {
        switch self {
        case .notDownloaded:
            return false
        case .downloading, .downloaded:
            return true
        }
    }
    
    static func == (lhs: EpisodeDownloadStatus, rhs: EpisodeDownloadStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notDownloaded, .notDownloaded):
            return true
        case (.downloading(let lhsDownload), .downloading(let rhsDownload)):
            return lhsDownload.id == rhsDownload.id
        case (.downloaded(let lhsAsset), .downloaded(let rhsAsset)):
            return lhsAsset.id == rhsAsset.id
        default:
            return false
        }
    }
}

/// Represents the download queue status of a download
enum DownloadQueueStatus: Equatable {
    /// Download is queued and not started
    case queued
    /// Download is currently being processed
    case downloading
    /// Download has been completed
    case completed
} 