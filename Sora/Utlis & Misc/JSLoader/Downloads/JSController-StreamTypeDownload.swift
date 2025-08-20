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
        aniListID: Int? = nil,
        malID: Int? = nil,
        isFiller: Bool? = nil,
        completionHandler: ((Bool, String) -> Void)? = nil
    ) {
        let streamType = module.metadata.streamType.lowercased()
        
        if streamType == "hls" || streamType == "m3u8" || url.absoluteString.contains(".m3u8") {
            Logger.shared.log("Using HLS download method", type: "Download")
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
                aniListID: aniListID,
                malID: malID,
                isFiller: isFiller,
                completionHandler: completionHandler
            )
        }else {
            Logger.shared.log("Using MP4 download method", type: "Download")
            downloadMP4(
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
                aniListID: aniListID,
                malID: malID,
                isFiller: isFiller,
                completionHandler: completionHandler
            )
        }
    }
}
