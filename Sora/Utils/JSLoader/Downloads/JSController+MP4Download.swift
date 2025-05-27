//
//  JSController+MP4Download.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import Foundation
import SwiftUI

// Extension for handling MP4 direct video downloads
extension JSController {
    
    /// Initiates a download for a given MP4 URL
    /// - Parameters:
    ///   - url: The MP4 URL to download
    ///   - headers: HTTP headers to use for the request
    ///   - title: Title for the download (optional)
    ///   - imageURL: Image URL for the content (optional)
    ///   - isEpisode: Whether this is an episode (defaults to false)
    ///   - showTitle: Title of the show this episode belongs to (optional)
    ///   - season: Season number (optional)
    ///   - episode: Episode number (optional)
    ///   - subtitleURL: Optional subtitle URL to download after video (optional)
    ///   - completionHandler: Called when the download is initiated or fails
    func downloadMP4(url: URL, headers: [String: String], title: String? = nil, 
                   imageURL: URL? = nil, isEpisode: Bool = false, 
                   showTitle: String? = nil, season: Int? = nil, episode: Int? = nil,
                   subtitleURL: URL? = nil,
                   completionHandler: ((Bool, String) -> Void)? = nil) {
        
        print("---- MP4 DOWNLOAD PROCESS STARTED ----")
        print("MP4 URL: \(url.absoluteString)")
        print("Headers: \(headers)")
        print("Title: \(title ?? "None")")
        print("Is Episode: \(isEpisode), Show: \(showTitle ?? "None"), Season: \(season?.description ?? "None"), Episode: \(episode?.description ?? "None")")
        if let subtitle = subtitleURL {
            print("Subtitle URL: \(subtitle.absoluteString)")
        }
        
        // Validate URL
        guard url.scheme == "http" || url.scheme == "https" else {
            completionHandler?(false, "Invalid URL scheme")
            return
        }
        
        // Create metadata for the download
        var metadata: AssetMetadata? = nil
        if let title = title {
            metadata = AssetMetadata(
                title: title,
                posterURL: imageURL,
                showTitle: showTitle,
                season: season,
                episode: episode,
                showPosterURL: imageURL
            )
        }
        
        // Determine download type based on isEpisode
        let downloadType: DownloadType = isEpisode ? .episode : .movie
        
        // Generate a unique download ID
        let downloadID = UUID()
        
        // Get access to the download directory
        guard let downloadDirectory = getPersistentDownloadDirectory() else {
            print("MP4 Download: Failed to get download directory")
            completionHandler?(false, "Failed to create download directory")
            return
        }
        
        // Generate a safe filename for the MP4 file
        let sanitizedTitle = title?.replacingOccurrences(of: "[^A-Za-z0-9 ._-]", with: "", options: .regularExpression) ?? "download"
        let filename = "\(sanitizedTitle)_\(downloadID.uuidString.prefix(8)).mp4"
        let destinationURL = downloadDirectory.appendingPathComponent(filename)
        
        // Create an active download object
        let activeDownload = JSActiveDownload(
            id: downloadID,
            originalURL: url,
            task: nil,
            queueStatus: .downloading,
            type: downloadType,
            metadata: metadata,
            title: title,
            imageURL: imageURL,
            subtitleURL: subtitleURL,
            headers: headers
        )
        
        // Add to active downloads
        activeDownloads.append(activeDownload)
        
        // Create request with headers
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Enhanced session configuration
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 60.0
        sessionConfig.timeoutIntervalForResource = 1800.0
        sessionConfig.httpMaximumConnectionsPerHost = 1
        sessionConfig.allowsCellularAccess = true
        
        // Create custom session with delegate
        let customSession = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        
        // Create the download task
        let downloadTask = customSession.downloadTask(with: request) { [weak self] (tempURL, response, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                defer {
                    // Clean up resources
                    self.cleanupDownloadResources(for: downloadID)
                }
                
                // Handle error cases - just remove from active downloads
                if let error = error {
                    print("MP4 Download Error: \(error.localizedDescription)")
                    self.removeActiveDownload(downloadID: downloadID)
                    completionHandler?(false, "Download failed: \(error.localizedDescription)")
                    return
                }
                
                // Validate response
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("MP4 Download: Invalid response")
                    self.removeActiveDownload(downloadID: downloadID)
                    completionHandler?(false, "Invalid server response")
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("MP4 Download HTTP Error: \(httpResponse.statusCode)")
                    self.removeActiveDownload(downloadID: downloadID)
                    completionHandler?(false, "Server error: \(httpResponse.statusCode)")
                    return
                }
                
                guard let tempURL = tempURL else {
                    print("MP4 Download: No temporary file URL")
                    self.removeActiveDownload(downloadID: downloadID)
                    completionHandler?(false, "Download data not available")
                    return
                }
                
                // Move file to final destination
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    print("MP4 Download: Successfully saved to \(destinationURL.path)")
                    
                    // Verify file size
                    let fileSize = try FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64 ?? 0
                    guard fileSize > 0 else {
                        throw NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Downloaded file is empty"])
                    }
                    
                    // Create downloaded asset
                    let downloadedAsset = DownloadedAsset(
                        name: title ?? url.lastPathComponent,
                        downloadDate: Date(),
                        originalURL: url,
                        localURL: destinationURL,
                        type: downloadType,
                        metadata: metadata,
                        subtitleURL: subtitleURL
                    )
                    
                    // Save asset
                    self.savedAssets.append(downloadedAsset)
                    self.saveAssets()
                    
                    // Update progress to complete and remove after delay
                    self.updateDownloadProgress(downloadID: downloadID, progress: 1.0)
                    
                    // Download subtitle if provided
                    if let subtitleURL = subtitleURL {
                        self.downloadSubtitle(subtitleURL: subtitleURL, assetID: downloadedAsset.id.uuidString)
                    }
                    
                    // Notify completion
                    NotificationCenter.default.post(name: NSNotification.Name("downloadCompleted"), object: downloadedAsset)
                    completionHandler?(true, "Download completed successfully")
                    
                    // Remove from active downloads after success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.removeActiveDownload(downloadID: downloadID)
                    }
                    
                } catch {
                    print("MP4 Download Error saving file: \(error.localizedDescription)")
                    self.removeActiveDownload(downloadID: downloadID)
                    completionHandler?(false, "Error saving download: \(error.localizedDescription)")
                }
            }
        }
        
        // Set up progress observation
        setupProgressObservation(for: downloadTask, downloadID: downloadID)
        
        // Store session reference
        storeSessionReference(session: customSession, for: downloadID)
        
        // Start download
        downloadTask.resume()
        print("MP4 Download: Task started for \(filename)")
        
        // Initial success callback
        completionHandler?(true, "Download started")
    }
    
    // MARK: - Helper Methods
    
    private func removeActiveDownload(downloadID: UUID) {
        activeDownloads.removeAll { $0.id == downloadID }
    }
    
    private func updateDownloadProgress(downloadID: UUID, progress: Double) {
        guard let index = activeDownloads.firstIndex(where: { $0.id == downloadID }) else { return }
        activeDownloads[index].progress = progress
    }
    
    private func setupProgressObservation(for task: URLSessionDownloadTask, downloadID: UUID) {
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updateDownloadProgress(downloadID: downloadID, progress: progress.fractionCompleted)
                NotificationCenter.default.post(name: NSNotification.Name("downloadProgressUpdated"), object: nil)
            }
        }
        
        if mp4ProgressObservations == nil {
            mp4ProgressObservations = [:]
        }
        mp4ProgressObservations?[downloadID] = observation
    }
    
    private func storeSessionReference(session: URLSession, for downloadID: UUID) {
        if mp4CustomSessions == nil {
            mp4CustomSessions = [:]
        }
        mp4CustomSessions?[downloadID] = session
    }
    
    private func cleanupDownloadResources(for downloadID: UUID) {
        mp4ProgressObservations?[downloadID] = nil
        mp4CustomSessions?[downloadID] = nil
    }
}

// MARK: - URLSessionDelegate
extension JSController: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        let host = challenge.protectionSpace.host
        print("MP4 Download: Handling server trust challenge for host: \(host)")
        
        // Define trusted hosts for MP4 downloads
        let trustedHosts = [
            "streamtales.cc",
            "frembed.xyz", 
            "vidclouds.cc"
        ]
        
        let isTrustedHost = trustedHosts.contains { host.contains($0) }
        let isCustomSession = mp4CustomSessions?.values.contains(session) == true
        
        if isTrustedHost || isCustomSession {
            guard let serverTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            
            print("MP4 Download: Accepting certificate for \(host)")
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            print("MP4 Download: Using default handling for \(host)")
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
