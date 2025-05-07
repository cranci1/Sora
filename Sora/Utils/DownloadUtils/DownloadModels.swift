//
//  DownloadModels.swift
//  Sora
//
//  Created by Francesco on 30/04/25.
//

import Foundation

// MARK: - Quality Preference Constants
enum DownloadQualityPreference: String, CaseIterable {
    case best = "Best"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    static var defaultPreference: DownloadQualityPreference {
        return .best
    }
    
    static var userDefaultsKey: String {
        return "downloadQuality"
    }
    
    /// Returns the current user preference for download quality
    static var current: DownloadQualityPreference {
        let storedValue = UserDefaults.standard.string(forKey: userDefaultsKey) ?? defaultPreference.rawValue
        return DownloadQualityPreference(rawValue: storedValue) ?? defaultPreference
    }
    
    /// Description of what each quality preference means
    var description: String {
        switch self {
        case .best:
            return "Highest available quality (largest file size)"
        case .high:
            return "High quality (720p or higher)"
        case .medium:
            return "Medium quality (480p-720p)"
        case .low:
            return "Lowest available quality (smallest file size)"
        }
    }
}

// MARK: - Download Types
enum DownloadType: String, Codable {
    case movie
    case episode
    
    var description: String {
        switch self {
        case .movie:
            return "Movie"
        case .episode:
            return "Episode"
        }
    }
}

// MARK: - Downloaded Asset Model
struct DownloadedAsset: Identifiable, Codable {
    let id: UUID
    var name: String
    let downloadDate: Date
    let originalURL: URL
    let localURL: URL
    let type: DownloadType
    let metadata: AssetMetadata?
    
    var fileSize: Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
            return attributes[.size] as? Int64
        } catch {
            print("Error getting file size: \(error)")
            return nil
        }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        downloadDate: Date,
        originalURL: URL,
        localURL: URL,
        type: DownloadType = .movie,
        metadata: AssetMetadata? = nil
    ) {
        self.id = id
        self.name = name
        self.downloadDate = downloadDate
        self.originalURL = originalURL
        self.localURL = localURL
        self.type = type
        self.metadata = metadata
    }
}

// MARK: - Active Download Model
struct ActiveDownload: Identifiable {
    let id: UUID
    let originalURL: URL
    var progress: Double
    let task: URLSessionTask
    let type: DownloadType
    let metadata: AssetMetadata?
    
    init(
        id: UUID = UUID(),
        originalURL: URL,
        progress: Double = 0,
        task: URLSessionTask,
        type: DownloadType = .movie,
        metadata: AssetMetadata? = nil
    ) {
        self.id = id
        self.originalURL = originalURL
        self.progress = progress
        self.task = task
        self.type = type
        self.metadata = metadata
    }
}

// MARK: - Asset Metadata
struct AssetMetadata: Codable {
    let title: String
    let overview: String?
    let posterURL: URL?
    let backdropURL: URL?
    let releaseDate: String?
    // Additional fields for episodes
    let showTitle: String?
    let season: Int?
    let episode: Int?
    
    init(
        title: String,
        overview: String? = nil,
        posterURL: URL? = nil,
        backdropURL: URL? = nil,
        releaseDate: String? = nil,
        showTitle: String? = nil,
        season: Int? = nil,
        episode: Int? = nil
    ) {
        self.title = title
        self.overview = overview
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.releaseDate = releaseDate
        self.showTitle = showTitle
        self.season = season
        self.episode = episode
    }
}
