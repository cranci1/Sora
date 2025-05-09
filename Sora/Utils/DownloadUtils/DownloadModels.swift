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
    // New fields for subtitle support
    let subtitleURL: URL?
    let localSubtitleURL: URL?
    
    var fileSize: Int64? {
        do {
            if FileManager.default.fileExists(atPath: localURL.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
                if let size = attributes[.size] as? Int64 {
                    return size
                } else if let size = attributes[.size] as? Int {
                    return Int64(size)
                } else if let size = attributes[.size] as? NSNumber {
                    return size.int64Value
                } else {
                    Logger.shared.log("Could not get file size as Int64 for: \(localURL.path)", type: "Warning")
                    return nil
                }
            } else {
                Logger.shared.log("File does not exist at path: \(localURL.path)", type: "Warning")
                return nil
            }
        } catch {
            Logger.shared.log("Error getting file size: \(error.localizedDescription) for \(localURL.path)", type: "Error")
            return nil
        }
    }
    
    // MARK: - New Grouping Properties
    
    /// Returns the anime title to use for grouping (show title for episodes, name for movies)
    var groupTitle: String {
        if type == .episode, let showTitle = metadata?.showTitle, !showTitle.isEmpty {
            return showTitle
        }
        // For movies or episodes without show title, use the asset name
        return name
    }
    
    /// Returns a display name suitable for showing in a list of episodes
    var episodeDisplayName: String {
        guard type == .episode else { return name }
        
        var display = name
        
        // Add season and episode prefix if available
        if let season = metadata?.season, let episode = metadata?.episode {
            display = "S\(season)E\(episode): \(name)"
        } else if let episode = metadata?.episode {
            display = "Episode \(episode): \(name)"
        }
        
        return display
    }
    
    /// Returns order priority for episodes within a show (by season and episode)
    var episodeOrderPriority: Int {
        guard type == .episode else { return 0 }
        
        // Calculate priority: Season number * 1000 + episode number
        let seasonValue = metadata?.season ?? 0
        let episodeValue = metadata?.episode ?? 0
        
        return (seasonValue * 1000) + episodeValue
    }
    
    // Add coding keys to ensure backward compatibility
    enum CodingKeys: String, CodingKey {
        case id, name, downloadDate, originalURL, localURL, type, metadata
        case subtitleURL, localSubtitleURL
    }
    
    // Custom decoding to handle optional new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode required fields
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        downloadDate = try container.decode(Date.self, forKey: .downloadDate)
        originalURL = try container.decode(URL.self, forKey: .originalURL)
        localURL = try container.decode(URL.self, forKey: .localURL)
        type = try container.decode(DownloadType.self, forKey: .type)
        metadata = try container.decodeIfPresent(AssetMetadata.self, forKey: .metadata)
        
        // Decode new optional fields
        subtitleURL = try container.decodeIfPresent(URL.self, forKey: .subtitleURL)
        localSubtitleURL = try container.decodeIfPresent(URL.self, forKey: .localSubtitleURL)
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        downloadDate: Date,
        originalURL: URL,
        localURL: URL,
        type: DownloadType = .movie,
        metadata: AssetMetadata? = nil,
        subtitleURL: URL? = nil,
        localSubtitleURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.downloadDate = downloadDate
        self.originalURL = originalURL
        self.localURL = localURL
        self.type = type
        self.metadata = metadata
        self.subtitleURL = subtitleURL
        self.localSubtitleURL = localSubtitleURL
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
    
    // Add the same grouping properties as DownloadedAsset for consistency
    var groupTitle: String {
        if type == .episode, let showTitle = metadata?.showTitle, !showTitle.isEmpty {
            return showTitle
        }
        // For movies or episodes without show title, use the title from metadata or fallback to URL
        return metadata?.title ?? originalURL.lastPathComponent
    }
    
    var episodeDisplayName: String {
        guard type == .episode else { return metadata?.title ?? originalURL.lastPathComponent }
        
        var display = metadata?.title ?? originalURL.lastPathComponent
        
        // Add season and episode prefix if available
        if let season = metadata?.season, let episode = metadata?.episode {
            display = "S\(season)E\(episode): \(display)"
        } else if let episode = metadata?.episode {
            display = "Episode \(episode): \(display)"
        }
        
        return display
    }
    
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

// MARK: - New Group Model
/// Represents a group of downloads (anime/show or movies)
struct DownloadGroup: Identifiable {
    let id = UUID()
    let title: String  // Anime title for shows
    let type: DownloadType
    var assets: [DownloadedAsset]
    var posterURL: URL?
    
    var assetCount: Int {
        return assets.count
    }
    
    var isShow: Bool {
        return type == .episode
    }
    
    var isAnime: Bool {
        return isShow
    }
    
    /// Returns the total file size of all assets in the group
    var totalFileSize: Int64 {
        var total: Int64 = 0
        for asset in assets {
            if let size = asset.fileSize {
                total += size
            }
        }
        return total
    }
    
    // For anime/TV shows, organize episodes by season then episode number
    func organizedEpisodes() -> [DownloadedAsset] {
        guard isShow else { return assets }
        return assets.sorted { $0.episodeOrderPriority < $1.episodeOrderPriority }
    }
}

// MARK: - Grouping Extensions
extension Array where Element == DownloadedAsset {
    /// Groups assets by anime title or movie
    func groupedByTitle() -> [DownloadGroup] {
        // First group by the anime title (show title for episodes, name for movies)
        let groupedDict = Dictionary(grouping: self) { asset in
            // For episodes, prioritize the showTitle from metadata
            if asset.type == .episode, let showTitle = asset.metadata?.showTitle, !showTitle.isEmpty {
                return showTitle
            }
            
            // For movies or episodes without proper metadata, use the asset name
            return asset.name
        }
        
        // Convert to array of DownloadGroup objects
        return groupedDict.map { (title, assets) in
            // Determine group type (if any asset is an episode, it's a show)
            let isShow = assets.contains { $0.type == .episode }
            let type: DownloadType = isShow ? .episode : .movie
            
            // Find poster URL (use first asset with a poster)
            let posterURL = assets.compactMap { $0.metadata?.posterURL }.first
            
            return DownloadGroup(
                title: title,
                type: type,
                assets: assets,
                posterURL: posterURL
            )
        }.sorted { $0.title < $1.title }
    }
    
    /// Sorts assets in a way suitable for flat list display
    func sortedForDisplay(by sortOption: DownloadView.SortOption) -> [DownloadedAsset] {
        switch sortOption {
        case .newest:
            return sorted { $0.downloadDate > $1.downloadDate }
        case .oldest:
            return sorted { $0.downloadDate < $1.downloadDate }
        case .title:
            return sorted { $0.name < $1.name }
        }
    }
}

// MARK: - Active Downloads Grouping
extension Array where Element == ActiveDownload {
    /// Groups active downloads by show title
    func groupedByTitle() -> [String: [ActiveDownload]] {
        let grouped = Dictionary(grouping: self) { download in
            return download.groupTitle
        }
        return grouped
    }
}
