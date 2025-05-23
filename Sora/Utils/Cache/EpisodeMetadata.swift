//
//  EpisodeMetadata.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import Foundation

/// Represents metadata for an episode, used for caching
struct EpisodeMetadata: Codable {
    /// Title of the episode
    let title: [String: String]
    
    /// Image URL for the episode
    let imageUrl: String
    
    /// AniList ID of the show
    let anilistId: Int
    
    /// Episode number
    let episodeNumber: Int
    
    /// When this metadata was cached
    let cacheDate: Date
    
    /// Unique cache key for this episode metadata
    var cacheKey: String {
        return "anilist_\(anilistId)_episode_\(episodeNumber)"
    }
    
    /// Initialize with the basic required data
    /// - Parameters:
    ///   - title: Dictionary of titles by language code
    ///   - imageUrl: URL of the episode thumbnail image
    ///   - anilistId: ID of the show in AniList
    ///   - episodeNumber: Number of the episode
    init(title: [String: String], imageUrl: String, anilistId: Int, episodeNumber: Int) {
        self.title = title
        self.imageUrl = imageUrl
        self.anilistId = anilistId
        self.episodeNumber = episodeNumber
        self.cacheDate = Date()
    }
} 