//
//  JSController-Downloads.swift
//  Sora
//
//  Created by Francesco on 30/04/25.
//

import Foundation
import AVKit
import AVFoundation

// Extension for download functionality
extension JSController {
    
    // MARK: - Download Session Setup
    
    // Class-level property to track asset validation
    private static var hasValidatedAssets = false
    
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
    ///   - subtitleURL: Optional URL for the subtitle file to download
    ///   - completionHandler: Called when download is initiated or fails
    func startDownload(url: URL, headers: [String: String], title: String? = nil, 
                     imageURL: URL? = nil, isEpisode: Bool = false, 
                     showTitle: String? = nil, season: Int? = nil, episode: Int? = nil,
                     subtitleURL: URL? = nil,
                     completionHandler: ((Bool, String) -> Void)? = nil) {
        
        // For episodes, first check if already downloaded by metadata (more reliable)
        if isEpisode && showTitle != nil && episode != nil {
            let episodeStatus = isEpisodeDownloadedOrInProgress(
                showTitle: showTitle!,
                episodeNumber: episode!,
                season: season ?? 1
            )
            
            if episodeStatus.isDownloadedOrInProgress {
                // Episode is already downloaded or being downloaded based on metadata
                let message: String
                if case .downloaded = episodeStatus {
                    message = "This episode has already been downloaded"
                } else {
                    message = "This episode is already being downloaded"
                }
                print("Episode already handled: \(message)")
                completionHandler?(false, message)
                return
            }
        }
        
        // Fallback to URL check for non-episodes or if metadata is incomplete
        if savedAssets.contains(where: { $0.originalURL == url }) {
            print("Asset already downloaded: \(url.absoluteString)")
            completionHandler?(false, "This content has already been downloaded")
            return
        }
        
        // Check if already downloading by URL
        if activeDownloads.contains(where: { $0.originalURL == url }) {
            print("Asset already being downloaded: \(url.absoluteString)")
            completionHandler?(false, "This content is already being downloaded")
            return
        }
        
        print("==== DOWNLOAD ATTEMPT ====")
        print("URL: \(url.absoluteString)")
        print("Headers: \(headers)")
        print("Title: \(title ?? "Unknown")")
        print("Image URL: \(imageURL?.absoluteString ?? "None")")
        print("Is Episode: \(isEpisode)")
        if isEpisode {
            print("Anime Title: \(showTitle ?? "Unknown")")
            print("Season: \(season ?? 0)")
            print("Episode: \(episode ?? 0)")
        }
        if let subtitleURL = subtitleURL {
            print("Subtitle URL: \(subtitleURL.absoluteString)")
        }
        
        // Extract domain for simplicity in debugging
        let domain = url.host ?? "unknown"
        print("Domain: \(domain)")
        
        // Create a URLRequest first (this is what CustomPlayer does)
        var request = URLRequest(url: url)
        
        // Add all headers precisely as received
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Get the headers from the request - this is key for AVURLAsset
        let requestHeaders = request.allHTTPHeaderFields ?? [:]
        print("Final request headers: \(requestHeaders)")
        
        // Create the asset with the EXACT same pattern as CustomPlayer
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": requestHeaders])
        
        // Log advanced debug information
        print("AVURLAsset created with URL: \(url.absoluteString)")
        print("AVURLAsset options: [\"AVURLAssetHTTPHeaderFieldsKey\": \(requestHeaders)]")
        
        // Generate a title for the download if not provided
        let downloadTitle = title ?? url.lastPathComponent
        
        // Ensure we have a proper anime title for episodes
        let animeTitle = isEpisode ? (showTitle ?? "Unknown Anime") : nil
        
        // Create metadata for the download with proper anime title
        let downloadType: DownloadType = isEpisode ? .episode : .movie
        let assetMetadata = AssetMetadata(
            title: downloadTitle,
            overview: nil,
            posterURL: imageURL,
            backdropURL: imageURL,
            releaseDate: nil,
            showTitle: animeTitle,
            season: season,
            episode: episode
        )
        
        // Create the download task with minimal options
        guard let task = downloadURLSession?.makeAssetDownloadTask(
            asset: asset,
            assetTitle: downloadTitle,
            assetArtworkData: nil,
            options: nil  // Remove unnecessary options that might interfere
        ) else {
            print("Failed to create download task")
            completionHandler?(false, "Failed to create download task")
            return
        }
        
        print("Download task created successfully")
        
        // Create an ActiveDownload and add it to the list
        let download = JSActiveDownload(
            id: UUID(),
            originalURL: url,
            progress: 0,
            task: task,
            type: downloadType,
            metadata: assetMetadata,
            title: downloadTitle,
            imageURL: imageURL,
            subtitleURL: subtitleURL // Store subtitle URL in the active download
        )
        
        activeDownloads.append(download)
        activeDownloadMap[task] = download.id
        
        // Start the download
        task.resume()
        print("Download task resumed")
        
        // Inform caller of success
        completionHandler?(true, "Download started")
        
        // Save the download state
        saveDownloadState()
    }
    
    /// Downloads a subtitle file for a video asset
    /// - Parameters:
    ///   - subtitleURL: The URL of the subtitle file to download
    ///   - assetID: The ID of the asset this subtitle is associated with
    private func downloadSubtitle(subtitleURL: URL, assetID: String) {
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
    private func saveAssets() {
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
    }
    
    /// Clean up a download task when it's completed or failed
    private func cleanupDownloadTask(_ task: URLSessionTask) {
        guard let downloadID = activeDownloadMap[task] else { return }
        
        activeDownloads.removeAll { $0.id == downloadID }
        activeDownloadMap.removeValue(forKey: task)
        saveDownloadState()
        
        print("Cleaned up download task")
    }
    
    /// Returns the directory for persistent downloads
    private func getPersistentDownloadDirectory() -> URL? {
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
        
        // Then check if it's currently being downloaded
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
        
        // Not downloaded or being downloaded
        return .notDownloaded
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
        }
        
        // Clean up the download task
        cleanupDownloadTask(assetDownloadTask)
        
        print("Download completed and moved to persistent storage: \(newAsset.name)")
        
        // Notify the user of successful download
        DispatchQueue.main.async {
            DropManager.shared.success("Download complete: \(newAsset.name)")
        }
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
            if let nsError = error as? NSError {
                print("Error domain: \(nsError.domain), code: \(nsError.code)")
                
                if let underlyingError = nsError.userInfo["NSUnderlyingError"] as? NSError {
                    print("Underlying error: \(underlyingError)")
                }
                
                for (key, value) in nsError.userInfo {
                    print("Error info - \(key): \(value)")
                }
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
    
    /// Called periodically as the download progresses
    func urlSession(_ session: URLSession,
                   assetDownloadTask: AVAssetDownloadTask,
                   didLoad timeRange: CMTimeRange,
                   totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                   timeRangeExpectedToLoad: CMTimeRange) {
        
        // Safely get the download ID and calculate progress
        guard let downloadID = activeDownloadMap[assetDownloadTask] else { 
            return 
        }
        
        // Calculate progress
        var percentComplete = 0.0
        
        for rangeValue in loadedTimeRanges {
            let range = rangeValue.timeRangeValue
            let duration = CMTimeGetSeconds(range.duration)
            percentComplete += duration
        }
        
        let totalDuration = CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
        if totalDuration > 0 {
            percentComplete = percentComplete / totalDuration
        }
        
        // Capture the progress value to use in the async block
        let finalProgress = percentComplete
        
        // Update the progress on the main thread with additional safety checks
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            
            // Find the index again inside the main thread to avoid race conditions
            guard let downloadIndex = strongSelf.activeDownloads.firstIndex(where: { $0.id == downloadID }) else {
                return
            }
            
            // Only update if the index is still valid
            if downloadIndex < strongSelf.activeDownloads.count {
                let download = strongSelf.activeDownloads[downloadIndex]
                strongSelf.activeDownloads[downloadIndex].progress = finalProgress
                
                // Post both notifications for UI updates
                NotificationCenter.default.post(name: NSNotification.Name("downloadStatusChanged"), object: nil)
                
                // Post the new progress notification with episode number if it's an episode
                if let episodeNumber = download.metadata?.episode {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("downloadProgressUpdated"),
                        object: nil,
                        userInfo: [
                            "episodeNumber": episodeNumber,
                            "progress": finalProgress
                        ]
                    )
                }
            }
        }
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
    let task: AVAssetDownloadTask
    let type: DownloadType
    var metadata: AssetMetadata?
    var title: String?
    var imageURL: URL?  // Added property to store image URL
    var subtitleURL: URL?  // Added property to store subtitle URL
    
    // Implement Equatable
    static func == (lhs: JSActiveDownload, rhs: JSActiveDownload) -> Bool {
        return lhs.id == rhs.id
    }
    
    init(
        id: UUID = UUID(),
        originalURL: URL,
        progress: Double = 0,
        task: AVAssetDownloadTask,
        type: DownloadType = .movie,
        metadata: AssetMetadata? = nil,
        title: String? = nil,
        imageURL: URL? = nil,  // Added parameter
        subtitleURL: URL? = nil  // Added parameter
    ) {
        self.id = id
        self.originalURL = originalURL
        self.progress = progress
        self.task = task
        self.type = type
        self.metadata = metadata
        self.title = title
        self.imageURL = imageURL  // Set the image URL
        self.subtitleURL = subtitleURL  // Set the subtitle URL
    }
}

/// Represents the download status of an episode
enum EpisodeDownloadStatus {
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
} 