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
        
        // Create metadata for the download
        var metadata: AssetMetadata? = nil
        if let title = title {
            metadata = AssetMetadata(
                title: title,
                posterURL: imageURL,
                showTitle: showTitle,
                season: season,
                episode: episode,
                showPosterURL: imageURL // Use the correct show poster URL
            )
        }
        
        // Determine download type based on isEpisode
        let downloadType: DownloadType = isEpisode ? .episode : .movie
        
        // Generate a unique download ID
        let downloadID = UUID()
        
        // Create an active download object
        let activeDownload = JSActiveDownload(
            id: downloadID,
            originalURL: url,
            task: nil,  // We'll set this after creating the task
            queueStatus: .queued,
            type: downloadType,
            metadata: metadata,
            title: title,
            imageURL: imageURL,
            subtitleURL: subtitleURL,
            headers: headers
        )
        
        // Add to active downloads
        activeDownloads.append(activeDownload)
        
        // Create a URL session task for downloading the MP4 file
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Get access to the download directory using the shared instance method
        guard let downloadDirectory = getPersistentDownloadDirectory() else {
            print("MP4 Download: Failed to get download directory")
            completionHandler?(false, "Failed to create download directory")
            return
        }
        
        // Generate a unique filename for the MP4 file
        let filename = "\(downloadID.uuidString).mp4"
        let destinationURL = downloadDirectory.appendingPathComponent(filename)
        
        // Use a session configuration that allows handling SSL issues
        let sessionConfig = URLSessionConfiguration.default
        // Set a longer timeout for large files
        sessionConfig.timeoutIntervalForRequest = 60.0
        sessionConfig.timeoutIntervalForResource = 600.0
        
        // Create a URL session that handles SSL certificate validation issues
        let customSession = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        
        // Create the download task with the custom session
        let downloadTask = customSession.downloadTask(with: request) { (tempURL, response, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("MP4 Download Error: \(error.localizedDescription)")
                    
                    // Update active download status
                    if let index = self.activeDownloads.firstIndex(where: { $0.id == downloadID }) {
                        self.activeDownloads[index].queueStatus = .queued
                    }
                    
                    // Clean up resources
                    self.mp4ProgressObservations?[downloadID] = nil
                    self.mp4CustomSessions?[downloadID] = nil
                    
                    // Remove the download after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.activeDownloads.removeAll { $0.id == downloadID }
                    }
                    
                    completionHandler?(false, "Download failed: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("MP4 Download: Invalid response")
                    completionHandler?(false, "Invalid server response")
                    return
                }
                
                if httpResponse.statusCode >= 400 {
                    print("MP4 Download HTTP Error: \(httpResponse.statusCode)")
                    completionHandler?(false, "Server error: \(httpResponse.statusCode)")
                    return
                }
                
                guard let tempURL = tempURL else {
                    print("MP4 Download: No temporary file URL")
                    completionHandler?(false, "Download data not available")
                    return
                }
                
                do {
                    // Move the temporary file to the permanent location
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    print("MP4 Download: Successfully moved file to \(destinationURL.path)")
                    
                    // Create the downloaded asset
                    let downloadedAsset = DownloadedAsset(
                        name: title ?? url.lastPathComponent,
                        downloadDate: Date(),
                        originalURL: url,
                        localURL: destinationURL,
                        type: downloadType,
                        metadata: metadata,
                        subtitleURL: subtitleURL
                    )
                    
                    // Add to saved assets
                    self.savedAssets.append(downloadedAsset)
                    self.saveAssets()
                    
                    // Update active download and remove after a delay
                    if let index = self.activeDownloads.firstIndex(where: { $0.id == downloadID }) {
                        self.activeDownloads[index].progress = 1.0
                        self.activeDownloads[index].queueStatus = .completed
                    }
                    
                    // Download subtitle if provided
                    if let subtitleURL = subtitleURL {
                        self.downloadSubtitle(subtitleURL: subtitleURL, assetID: downloadedAsset.id.uuidString)
                    }
                    
                    // Notify observers - use downloadCompleted since the download finished
                    NotificationCenter.default.post(name: NSNotification.Name("downloadCompleted"), object: nil)
                    
                    completionHandler?(true, "Download completed successfully")
                    
                    // Clean up resources
                    self.mp4ProgressObservations?[downloadID] = nil
                    self.mp4CustomSessions?[downloadID] = nil
                    
                    // Remove the completed download from active list after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.activeDownloads.removeAll { $0.id == downloadID }
                    }
                    
                } catch {
                    print("MP4 Download Error moving file: \(error.localizedDescription)")
                    completionHandler?(false, "Error saving download: \(error.localizedDescription)")
                }
            }
        }
        
        // Set up progress tracking
        downloadTask.resume()
        
        // Update the task in the active download
        if let index = activeDownloads.firstIndex(where: { $0.id == downloadID }) {
            activeDownloads[index].queueStatus = .downloading
            
            // Store reference to the downloadTask directly - no need to access private properties
            print("MP4 Download: Task started")
            // We can't directly store URLSessionDownloadTask in place of AVAssetDownloadTask
            // Just continue tracking progress separately
        }
        
        // Set up progress observation - fix the key path specification
        let observation = downloadTask.progress.observe(\Progress.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                if let index = self.activeDownloads.firstIndex(where: { $0.id == downloadID }) {
                    self.activeDownloads[index].progress = progress.fractionCompleted
                    
                    // Notify observers of progress update
                    NotificationCenter.default.post(name: NSNotification.Name("downloadProgressUpdated"), object: nil)
                }
            }
        }
        
        // Store the observation somewhere to keep it alive - using nonatomic property from main class
        if self.mp4ProgressObservations == nil {
            self.mp4ProgressObservations = [:]
        }
        self.mp4ProgressObservations?[downloadID] = observation
        
        // Store the custom session to keep it alive until download is complete
        if self.mp4CustomSessions == nil {
            self.mp4CustomSessions = [:]
        }
        self.mp4CustomSessions?[downloadID] = customSession
        
        // Notify that download started successfully
        completionHandler?(true, "Download started")
    }
}

// Extension for handling SSL certificate validation for MP4 downloads
extension JSController: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Handle SSL/TLS certificate validation
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let host = challenge.protectionSpace.host
            print("MP4 Download: Handling server trust challenge for host: \(host)")
            
            // Accept the server's certificate for known problematic domains
            // or for domains in our custom session downloads
            if host.contains("streamtales.cc") || 
               host.contains("frembed.xyz") || 
               host.contains("vidclouds.cc") ||
               self.mp4CustomSessions?.values.contains(session) == true {
                
                if let serverTrust = challenge.protectionSpace.serverTrust {
                    // Log detailed info about the trust
                    print("MP4 Download: Accepting certificate for \(host)")
                    
                    let credential = URLCredential(trust: serverTrust)
                    completionHandler(.useCredential, credential)
                    return
                }
            }
        }
        
        // For other authentication challenges, use default handling
        print("MP4 Download: Using default handling for auth challenge")
        completionHandler(.performDefaultHandling, nil)
    }
} 