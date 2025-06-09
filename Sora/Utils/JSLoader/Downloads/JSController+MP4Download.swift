//
//  JSController+MP4Download.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import Foundation
import SwiftUI
import AVFoundation

// Extension for handling MP4 direct video downloads using AVAssetDownloadTask
extension JSController {
    
    /// Initiates a download for a given MP4 URL using the existing AVAssetDownloadURLSession
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
                   subtitleURL: URL? = nil, showPosterURL: URL? = nil,
                   completionHandler: ((Bool, String) -> Void)? = nil) {
        
        // Validate URL
        guard url.scheme == "http" || url.scheme == "https" else {
            completionHandler?(false, "Invalid URL scheme")
            return
        }
        
        // Ensure download session is available
        guard let downloadSession = downloadURLSession else {
            completionHandler?(false, "Download session not available")
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
                showPosterURL: showPosterURL ?? imageURL
            )
        }
        
        // Determine download type based on isEpisode
        let downloadType: DownloadType = isEpisode ? .episode : .movie
        
        // Generate a unique download ID
        let downloadID = UUID()
        
        // Create AVURLAsset with headers passed through AVURLAssetHTTPHeaderFieldsKey
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": headers
        ])
        
        // Create AVAssetDownloadTask using existing session
        guard let downloadTask = downloadSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: title ?? url.lastPathComponent,
            assetArtworkData: nil,
            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 2_000_000]
        ) else {
            completionHandler?(false, "Failed to create download task")
            return
        }
        
        // Create an active download object
        let activeDownload = JSActiveDownload(
            id: downloadID,
            originalURL: url,
            progress: 0.0,
            task: downloadTask,
            urlSessionTask: nil,
            queueStatus: .downloading,
            type: downloadType,
            metadata: metadata,
            title: title,
            imageURL: imageURL,
            subtitleURL: subtitleURL,
            asset: asset,
            headers: headers,
            module: nil
        )
        
        // Add to active downloads and tracking
        activeDownloads.append(activeDownload)
        activeDownloadMap[downloadTask] = downloadID
        
        // Set up progress observation for MP4 downloads
        setupMP4ProgressObservation(for: downloadTask, downloadID: downloadID)
        
        // Start the download
        downloadTask.resume()
        
        // Post notification for UI updates using NotificationCenter directly since postDownloadNotification is private
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("downloadStatusChanged"), object: nil)
        }
        
        // Initial success callback
        completionHandler?(true, "Download started")
    }
    
    // MARK: - MP4 Progress Observation
    
    /// Sets up progress observation for MP4 downloads using AVAssetDownloadTask
    /// Since AVAssetDownloadTask doesn't provide progress for single MP4 files through delegate methods,
    /// we observe the task's progress property directly
    private func setupMP4ProgressObservation(for task: AVAssetDownloadTask, downloadID: UUID) {
        let observation = task.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Update download progress using existing infrastructure
                self.updateMP4DownloadProgress(task: task, progress: progress.fractionCompleted)
                
                // Post notification for UI updates
                NotificationCenter.default.post(name: NSNotification.Name("downloadProgressChanged"), object: nil)
            }
        }
        
        // Store observation for cleanup using existing property from main JSController class
        if mp4ProgressObservations == nil {
            mp4ProgressObservations = [:]
        }
        mp4ProgressObservations?[downloadID] = observation
    }
    
    /// Updates download progress for a specific MP4 task (avoiding name collision with existing method)
    private func updateMP4DownloadProgress(task: AVAssetDownloadTask, progress: Double) {
        guard let downloadID = activeDownloadMap[task],
              let downloadIndex = activeDownloads.firstIndex(where: { $0.id == downloadID }) else {
            return
        }
        
        // Update progress using existing mechanism
        activeDownloads[downloadIndex].progress = progress
    }
    
    /// Cleans up MP4 progress observation for a specific download
    func cleanupMP4ProgressObservation(for downloadID: UUID) {
        mp4ProgressObservations?[downloadID]?.invalidate()
        mp4ProgressObservations?[downloadID] = nil
    }
}
