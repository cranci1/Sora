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
        
        // Create a URL request with the headers
        var urlRequest = URLRequest(url: url)
        for (key, value) in headers {
            urlRequest.addValue(value, forHTTPHeaderField: key)
        }
        
        // Log the request details
        print("Starting download for URL: \(url.absoluteString)")
        print("Headers: \(headers)")
        
        // Create an asset with the headers
        let assetOptions = ["AVURLAssetHTTPHeaderFieldsKey": headers]
        let asset = AVURLAsset(url: url, options: assetOptions)
        
        // Generate a title for the download if not provided
        let downloadTitle = title ?? url.lastPathComponent
        
        // Create the download task
        guard let task = downloadURLSession?.makeAssetDownloadTask(
            asset: asset,
            assetTitle: downloadTitle,
            assetArtworkData: nil,
            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 500_000]
        ) else {
            print("Failed to create download task")
            completionHandler?(false, "Failed to create download task")
            return
        }
        
        // Create an ActiveDownload and add it to the list
        let download = ActiveDownload(
            id: UUID(),
            originalURL: url,
            progress: 0,
            task: task,
            type: .movie
        )
        
        activeDownloads.append(download)
        activeDownloadMap[task] = download.id
        
        // Start the download
        task.resume()
        
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
                "type": download.type.rawValue
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
            name: download.task.originalRequest?.url?.lastPathComponent ?? "Unknown",
            downloadDate: Date(),
            originalURL: download.originalURL,
            localURL: location,
            type: download.type,
            metadata: download.metadata
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
            print("Download error: \(error.localizedDescription)")
            
            // Check if there's a system network error 
            if let urlError = error as? URLError, 
               urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                print("Network error: \(urlError.localizedDescription)")
                
                DispatchQueue.main.async {
                    DropManager.shared.error("Network error: \(urlError.localizedDescription)")
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
        let progress = loadedTimeRanges
            .map { $0.timeRangeValue.duration.seconds / timeRangeExpectedToLoad.duration.seconds }
            .reduce(0, +)
        
        // Update the progress
        activeDownloads[downloadIndex].progress = progress
        
        // Notify UI to update every 5% or so
        if Int(progress * 100) % 5 == 0 {
            print("Download progress: \(Int(progress * 100))%")
        }
    }
}

// MARK: - URLSessionTaskDelegate
extension JSController: URLSessionTaskDelegate {
    /// Called when a redirect is received
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Allow redirects but ensure headers are maintained
        var redirectRequest = request
        
        if let originalRequest = task.originalRequest, 
           let headers = originalRequest.allHTTPHeaderFields {
            
            for (key, value) in headers {
                if redirectRequest.value(forHTTPHeaderField: key) == nil {
                    redirectRequest.addValue(value, forHTTPHeaderField: key)
                }
            }
        }
        
        completionHandler(redirectRequest)
    }
} 