//
//  JSController-StreamTypeDownload.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import Foundation
import SwiftUI

// Extension that integrates streamType-aware downloading
extension JSController {
    
    /// Main entry point for downloading that determines the appropriate download method based on streamType
    /// - Parameters:
    ///   - url: The URL to download
    ///   - headers: HTTP headers to use for the request
    ///   - title: Title for the download (optional)
    ///   - imageURL: Image URL for the content (optional)
    ///   - module: The module being used for the download, used to determine streamType
    ///   - isEpisode: Whether this is an episode (defaults to false)
    ///   - showTitle: Title of the show this episode belongs to (optional)
    ///   - season: Season number (optional)
    ///   - episode: Episode number (optional)
    ///   - subtitleURL: Optional subtitle URL to download after video (optional)
    ///   - completionHandler: Called when the download is initiated or fails
    func downloadWithStreamTypeSupport(
        url: URL, 
        headers: [String: String], 
        title: String? = nil,
        imageURL: URL? = nil, 
        module: ScrapingModule,
        isEpisode: Bool = false, 
        showTitle: String? = nil, 
        season: Int? = nil, 
        episode: Int? = nil,
        subtitleURL: URL? = nil,
        showPosterURL: URL? = nil,
        completionHandler: ((Bool, String) -> Void)? = nil
    ) {
        print("---- STREAM TYPE DOWNLOAD PROCESS STARTED ----")
        print("Original URL: \(url.absoluteString)")
        print("Stream Type: \(module.metadata.streamType)")
        print("Headers: \(headers)")
        print("Title: \(title ?? "None")")
        print("Is Episode: \(isEpisode), Show: \(showTitle ?? "None"), Season: \(season?.description ?? "None"), Episode: \(episode?.description ?? "None")")
        if let subtitle = subtitleURL {
            print("Subtitle URL: \(subtitle.absoluteString)")
        }
        
        // Check the stream type from the module metadata
        let streamType = module.metadata.streamType.lowercased()
        
        // Determine which download method to use based on streamType
        if streamType == "mp4" || streamType == "direct" || url.absoluteString.contains(".mp4") {
            print("MP4 URL detected - downloading not supported")
            completionHandler?(false, "MP4 direct downloads are not supported. Please use HLS streams for downloading.")
            return
        } else if streamType == "hls" || streamType == "m3u8" || url.absoluteString.contains(".m3u8") {
            print("Using HLS download method")
            downloadWithM3U8Support(
                url: url,
                headers: headers,
                title: title,
                imageURL: imageURL,
                isEpisode: isEpisode,
                showTitle: showTitle,
                season: season,
                episode: episode,
                subtitleURL: subtitleURL,
                showPosterURL: showPosterURL,
                completionHandler: completionHandler
            )
        } else {
            // Default to M3U8 method for unknown types, as it has fallback mechanisms
            print("Using default HLS download method for unknown stream type: \(streamType)")
            downloadWithM3U8Support(
                url: url,
                headers: headers,
                title: title,
                imageURL: imageURL,
                isEpisode: isEpisode,
                showTitle: showTitle,
                season: season,
                episode: episode,
                subtitleURL: subtitleURL,
                showPosterURL: showPosterURL,
                completionHandler: completionHandler
            )
        }
    }
} 