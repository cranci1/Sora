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
    ///   - completionHandler: Called when download is initiated or fails
    func startDownload(url: URL, headers: [String: String], title: String? = nil, 
                     imageURL: URL? = nil, isEpisode: Bool = false, 
                     showTitle: String? = nil, season: Int? = nil, episode: Int? = nil,
                     completionHandler: ((Bool, String) -> Void)? = nil) {
        // Check if already downloaded
        if savedAssets.contains(where: { $0.originalURL == url }) {
            print("Asset already downloaded: \(url.absoluteString)")
            completionHandler?(false, "This content has already been downloaded")
            return
        }
        
        // Check if already downloading
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
            imageURL: imageURL
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
    
    // MARK: - Asset Management
    
    /// Load saved assets from UserDefaults
    func loadSavedAssets() {
        // First, migrate any existing files from Documents to Application Support
        migrateExistingFilesToPersistentStorage()
        
        guard let data = UserDefaults.standard.data(forKey: "downloadedAssets") else { 
            print("No saved assets found")
            return 
        }
        
        do {
            savedAssets = try JSONDecoder().decode([DownloadedAsset].self, from: data)
            print("Loaded \(savedAssets.count) saved assets")
            
            // Verify that saved assets exist in the persistent storage location
            validateAndUpdateAssetLocations()
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
                        metadata: asset.metadata
                    )
                    updatedAssets = true
                }
            }
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
            metadata: download.metadata  // Use the metadata we created when starting the download
        )
        
        // Add to saved assets and save
        savedAssets.append(newAsset)
        saveAssets()
        
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
                strongSelf.activeDownloads[downloadIndex].progress = finalProgress
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
struct JSActiveDownload: Identifiable {
    let id: UUID
    let originalURL: URL
    var progress: Double
    let task: AVAssetDownloadTask
    let type: DownloadType
    var metadata: AssetMetadata?
    var title: String?
    var imageURL: URL?  // Added property to store image URL
    
    init(
        id: UUID = UUID(),
        originalURL: URL,
        progress: Double = 0,
        task: AVAssetDownloadTask,
        type: DownloadType = .movie,
        metadata: AssetMetadata? = nil,
        title: String? = nil,
        imageURL: URL? = nil  // Added parameter
    ) {
        self.id = id
        self.originalURL = originalURL
        self.progress = progress
        self.task = task
        self.type = type
        self.metadata = metadata
        self.title = title
        self.imageURL = imageURL  // Set the image URL
    }
} 