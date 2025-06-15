//
//  VideoWatchingActivity.swift
//  Sora
//
//  Created by Francesco on 15/06/25.
//

import UIKit
import Foundation
import GroupActivities

struct VideoWatchingActivity: GroupActivity {
    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = mediaTitle
        metadata.subtitle = "Episode \(episodeNumber)"
        
        if let imageData = episodeImageData,
           let uiImage = UIImage(data: imageData) {
            metadata.previewImage = uiImage.cgImage
        }
        
        metadata.type = .watchTogether
        return metadata
    }
    
    let mediaTitle: String
    let episodeNumber: Int
    let streamUrl: String
    let subtitles: String
    let aniListID: Int
    let fullUrl: String
    let headers: [String: String]?
    let episodeImageUrl: String
    let episodeImageData: Data?
    let totalEpisodes: Int
    let tmdbID: Int?
    let isMovie: Bool
    let seasonNumber: Int
    
    init(mediaTitle: String,
         episodeNumber: Int,
         streamUrl: String,
         subtitles: String = "",
         aniListID: Int = 0,
         fullUrl: String,
         headers: [String: String]? = nil,
         episodeImageUrl: String = "",
         episodeImageData: Data? = nil,
         totalEpisodes: Int = 0,
         tmdbID: Int? = nil,
         isMovie: Bool = false,
         seasonNumber: Int = 1) {
        self.mediaTitle = mediaTitle
        self.episodeNumber = episodeNumber
        self.streamUrl = streamUrl
        self.subtitles = subtitles
        self.aniListID = aniListID
        self.fullUrl = fullUrl
        self.headers = headers
        self.episodeImageUrl = episodeImageUrl
        self.episodeImageData = episodeImageData
        self.totalEpisodes = totalEpisodes
        self.tmdbID = tmdbID
        self.isMovie = isMovie
        self.seasonNumber = seasonNumber
    }
}
