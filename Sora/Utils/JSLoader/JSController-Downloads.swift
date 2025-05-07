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
    ///   - completionHandler: Called when download is initiated or fails
    func startDownload(url: URL, headers: [String: String], title: String? = nil, completionHandler: ((Bool, String) -> Void)? = nil) {
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
            type: .movie,  // Default to movie, can be refined with metadata
            title: downloadTitle
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
        guard let data = UserDefaults.standard.data(forKey: "downloadedAssets") else { 
            print("No saved assets found")
            return 
        }
        
        do {
            savedAssets = try JSONDecoder().decode([DownloadedAsset].self, from: data)
            print("Loaded \(savedAssets.count) saved assets")
        } catch {
            print("Error loading saved assets: \(error.localizedDescription)")
        }
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
            try FileManager.default.removeItem(at: asset.localURL)
            savedAssets.removeAll { $0.id == asset.id }
            saveAssets()
            print("Deleted asset: \(asset.name)")
        } catch {
            print("Error deleting asset: \(error.localizedDescription)")
        }
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
        
        // Create a new DownloadedAsset
        let newAsset = DownloadedAsset(
            name: download.title ?? download.originalURL.lastPathComponent,
            downloadDate: Date(),
            originalURL: download.originalURL,
            localURL: location,
            type: .movie,  // Default to movie, can be refined with metadata
            metadata: nil  // Metadata can be added in future versions
        )
        
        // Add to saved assets and save
        savedAssets.append(newAsset)
        saveAssets()
        
        // Clean up the download task
        cleanupDownloadTask(assetDownloadTask)
        
        print("Download completed: \(newAsset.name)")
        
        // Notify the user of successful download
        DispatchQueue.main.async {
            DropManager.shared.success("Download complete: \(newAsset.name)")
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
        
        guard let downloadID = activeDownloadMap[assetDownloadTask],
              let downloadIndex = activeDownloads.firstIndex(where: { $0.id == downloadID }) else { 
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
        
        // Update the progress on the main thread
        DispatchQueue.main.async {
            self.activeDownloads[downloadIndex].progress = percentComplete
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
    
    init(
        id: UUID = UUID(),
        originalURL: URL,
        progress: Double = 0,
        task: AVAssetDownloadTask,
        type: DownloadType = .movie,
        metadata: AssetMetadata? = nil,
        title: String? = nil
    ) {
        self.id = id
        self.originalURL = originalURL
        self.progress = progress
        self.task = task
        self.type = type
        self.metadata = metadata
        self.title = title
    }
} 