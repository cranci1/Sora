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
struct DownloadedAsset: Identifiable, Codable, Equatable {
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
    
    // For caching purposes, but not stored as part of the codable object
    private var _cachedFileSize: Int64? = nil
    
    // Implement Equatable
    static func == (lhs: DownloadedAsset, rhs: DownloadedAsset) -> Bool {
        return lhs.id == rhs.id
    }
    
    /// Returns the combined file size of the video file and subtitle file (if exists)
    var fileSize: Int64 {
        // This implementation calculates file size without caching it in the struct property
        // Instead we'll use a static cache dictionary
        let cacheKey = localURL.path
        
        // Check the static cache
        if let size = DownloadedAsset.fileSizeCache[cacheKey] {
            return size
        }
        
        var totalSize: Int64 = 0
        let fileManager = FileManager.default
        
        // Get video file size
        if fileManager.fileExists(atPath: localURL.path) {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: localURL.path)
                if let size = attributes[.size] as? Int64 {
                    totalSize += size
                } else if let size = attributes[.size] as? Int {
                    totalSize += Int64(size)
                } else if let size = attributes[.size] as? NSNumber {
                    totalSize += size.int64Value
                } else {
                    Logger.shared.log("Could not get file size as Int64 for: \(localURL.path)", type: "Warning")
                }
            } catch {
                Logger.shared.log("Error getting file size: \(error.localizedDescription) for \(localURL.path)", type: "Error")
            }
        } else {
            Logger.shared.log("Video file does not exist at path: \(localURL.path)", type: "Warning")
        }
        
        // Add subtitle file size if it exists
        if let subtitlePath = localSubtitleURL?.path, fileManager.fileExists(atPath: subtitlePath) {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: subtitlePath)
                if let size = attributes[.size] as? Int64 {
                    totalSize += size
                } else if let size = attributes[.size] as? Int {
                    totalSize += Int64(size)
                } else if let size = attributes[.size] as? NSNumber {
                    totalSize += size.int64Value
                }
            } catch {
                Logger.shared.log("Error getting subtitle file size: \(error.localizedDescription)", type: "Warning")
            }
        }
        
        // Store in static cache
        DownloadedAsset.fileSizeCache[cacheKey] = totalSize
        return totalSize
    }
    
    /// Global file size cache for performance
    private static var fileSizeCache: [String: Int64] = [:]
    
    /// Clears the global file size cache
    static func clearFileSizeCache() {
        fileSizeCache.removeAll()
    }
    
    /// Returns true if the main video file exists
    var fileExists: Bool {
        return FileManager.default.fileExists(atPath: localURL.path)
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
        
        // Initialize cache
        _cachedFileSize = nil
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
struct ActiveDownload: Identifiable, Equatable {
    let id: UUID
    let originalURL: URL
    var progress: Double
    let task: URLSessionTask
    let type: DownloadType
    let metadata: AssetMetadata?
    
    // Implement Equatable
    static func == (lhs: ActiveDownload, rhs: ActiveDownload) -> Bool {
        return lhs.id == rhs.id
    }
    
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
    var id = UUID()
    let title: String  // Anime title for shows
    let type: DownloadType
    var assets: [DownloadedAsset]
    var posterURL: URL?
    
    // Cache key for this group
    private var cacheKey: String {
        return "\(id)-\(title)-\(assets.count)"
    }
    
    // Static file size cache
    private static var fileSizeCache: [String: Int64] = [:]
    
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
        // Check if we have a cached size for this group
        let key = cacheKey
        if let cachedSize = DownloadGroup.fileSizeCache[key] {
            return cachedSize
        }
        
        // Calculate total size from all assets
        let total = assets.reduce(0) { runningTotal, asset in
            return runningTotal + asset.fileSize
        }
        
        // Store in static cache
        DownloadGroup.fileSizeCache[key] = total
        return total
    }
    
    /// Returns the count of assets that actually exist on disk
    var existingAssetsCount: Int {
        return assets.filter { $0.fileExists }.count
    }
    
    /// Returns true if all assets in this group exist
    var allAssetsExist: Bool {
        return existingAssetsCount == assets.count
    }
    
    /// Clear the file size cache for all groups
    static func clearFileSizeCache() {
        fileSizeCache.removeAll()
    }
    
    // For anime/TV shows, organize episodes by season then episode number
    func organizedEpisodes() -> [DownloadedAsset] {
        guard isShow else { return assets }
        return assets.sorted { $0.episodeOrderPriority < $1.episodeOrderPriority }
    }
    
    /// Refresh the calculated size for this group
    mutating func refreshFileSize() {
        DownloadGroup.fileSizeCache.removeValue(forKey: cacheKey)
        _ = totalFileSize
    }
    
    init(title: String, type: DownloadType, assets: [DownloadedAsset], posterURL: URL? = nil) {
        self.title = title
        self.type = type
        self.assets = assets
        self.posterURL = posterURL
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
