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
            return "Maximum quality available (largest file size)"
        case .high:
            return "High quality (720p or better)"
        case .medium:
            return "Medium quality (480p to 720p)"
        case .low:
            return "Minimum quality available (smallest file size)"
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
        let subtitlePathString = localSubtitleURL?.path ?? ""
        let cacheKey = localURL.path + ":" + subtitlePathString
        
        // Check the static cache first
        if let size = DownloadedAsset.fileSizeCache[cacheKey] {
            return size
        }
        
        // Check if this asset is currently being downloaded (avoid expensive calculations during active downloads)
        if isCurrentlyBeingDownloaded() {
            // Return cached size if available, otherwise return 0 and schedule background calculation
            if let lastKnownSize = DownloadedAsset.lastKnownSizes[cacheKey] {
                // Schedule a background update for when download completes
                scheduleBackgroundSizeCalculation(cacheKey: cacheKey)
                return lastKnownSize
            } else {
                // Return 0 for actively downloading files that we haven't calculated yet
                return 0
            }
        }
        
        // For non-active downloads, calculate the size normally
        let calculatedSize = calculateFileSizeInternal()
        
        // Store in both caches
        DownloadedAsset.fileSizeCache[cacheKey] = calculatedSize
        DownloadedAsset.lastKnownSizes[cacheKey] = calculatedSize
        
        return calculatedSize
    }
    
    /// Check if this asset is currently being downloaded
    public func isCurrentlyBeingDownloaded() -> Bool {
        // Access JSController to check active downloads
        let activeDownloads = JSController.shared.activeDownloads
        
        // Check if any active download matches this asset's path
        for download in activeDownloads {
            // Compare based on the file name or title
            if let downloadTitle = download.title, downloadTitle == name {
                return true
            }
            
            // Also compare based on URL path if titles don't match
            if download.originalURL.lastPathComponent.contains(name) || 
               name.contains(download.originalURL.lastPathComponent) {
                return true
            }
        }
        
        return false
    }
    
    /// Schedule a background calculation for when the download completes
    private func scheduleBackgroundSizeCalculation(cacheKey: String) {
        DispatchQueue.global(qos: .background).async {
            // Check if download is still active before calculating
            if !self.isCurrentlyBeingDownloaded() {
                let size = self.calculateFileSizeInternal()
                
                DispatchQueue.main.async {
                    // Update caches on main thread
                    DownloadedAsset.fileSizeCache[cacheKey] = size
                    DownloadedAsset.lastKnownSizes[cacheKey] = size
                    
                    // Post a notification that file size has been updated
                    NotificationCenter.default.post(
                        name: NSNotification.Name("fileSizeUpdated"),
                        object: nil,
                        userInfo: ["assetId": self.id.uuidString]
                    )
                }
            }
        }
    }
    
    /// Internal method to calculate file size (separated for reuse)
    public func calculateFileSizeInternal() -> Int64 {
        var totalSize: Int64 = 0
        let fileManager = FileManager.default
        
        // Get video file or directory size
        if fileManager.fileExists(atPath: localURL.path) {
            // Check if it's a .movpkg directory or a regular file
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: localURL.path, isDirectory: &isDirectory)
            
            if isDirectory.boolValue {
                // If it's a directory (like .movpkg), calculate size of all contained files
                totalSize += calculateDirectorySize(localURL)
                Logger.shared.log("Calculated directory size for .movpkg: \(totalSize) bytes", type: "Info")
            } else {
                // If it's a single file, get its size
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
        
        return totalSize
    }
    
    /// Calculates the size of all files in a directory recursively
    private func calculateDirectorySize(_ directoryURL: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        do {
            // Get all content URLs
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [])
            
            // Calculate size for each item
            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                
                if let isDirectory = resourceValues.isDirectory, isDirectory {
                    // If it's a directory, recursively calculate its size
                    totalSize += calculateDirectorySize(url)
                } else {
                    // If it's a file, add its size
                    if let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }
        } catch {
            Logger.shared.log("Error calculating directory size: \(error.localizedDescription)", type: "Error")
        }
        
        return totalSize
    }
    
    /// Global file size cache for performance
    private static var fileSizeCache: [String: Int64] = [:]
    
    /// Global last known sizes cache for performance
    private static var lastKnownSizes: [String: Int64] = [:]
    
    /// Clears the global file size cache
    static func clearFileSizeCache() {
        fileSizeCache.removeAll()
        lastKnownSizes.removeAll()
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
        
        // Return the name directly since titles typically already contain episode information
        return name
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
           if type == .episode,
              let showTitle = metadata?.showTitle,
              !showTitle.isEmpty {
               return showTitle
           }
           return metadata?.title ?? originalURL.lastPathComponent
       }
    
    var episodeDisplayName: String {
        guard type == .episode else {
            return metadata?.title ?? originalURL.lastPathComponent
        }
        
        // Extract base episode number from metadata or default to 1
        let episodeNumber = metadata?.episode ?? 1
        let base = "Episode \(episodeNumber)"
        
        // Check if we have a valid title that's different from the base
        if let title = metadata?.title, !title.isEmpty, title != base {
            return "\(base): \(title)"
        } else {
            return base
        }
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
    let showPosterURL: URL? // Main show poster URL (distinct from episode-specific images)
    let episodeTitle: String?
    let seasonNumber: Int?
    /// Indicates whether this episode is a filler (derived from metadata at download time)
    let isFiller: Bool?
    
    init(
        title: String,
        overview: String? = nil,
        posterURL: URL? = nil,
        backdropURL: URL? = nil,
        releaseDate: String? = nil,
        showTitle: String? = nil,
        season: Int? = nil,
        episode: Int? = nil,
        showPosterURL: URL? = nil,
        episodeTitle: String? = nil,
        seasonNumber: Int? = nil,
        isFiller: Bool? = nil
    ) {
        self.title = title
        self.overview = overview
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.releaseDate = releaseDate
        self.showTitle = showTitle
        self.season = season
        self.episode = episode
        self.showPosterURL = showPosterURL
        self.episodeTitle = episodeTitle
        self.seasonNumber = seasonNumber
        self.isFiller = isFiller
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
    
    // Static last known group sizes cache for performance during active downloads
    private static var lastKnownGroupSizes: [String: Int64] = [:]
    
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
        
        // Check if any assets in this group are currently being downloaded
        let hasActiveDownloads = assets.contains { asset in
            return asset.isCurrentlyBeingDownloaded()
        }
        
        if hasActiveDownloads {
            // If any downloads are active, return last known size or schedule background calculation
            if let lastKnownSize = DownloadGroup.lastKnownGroupSizes[key] {
                // Schedule a background update for when downloads complete
                scheduleBackgroundGroupSizeCalculation(cacheKey: key)
                return lastKnownSize
            } else {
                // Return 0 for groups with active downloads that we haven't calculated yet
                return 0
            }
        }
        
        // For groups without active downloads, calculate the size normally
        let total = assets.reduce(0) { runningTotal, asset in
            return runningTotal + asset.fileSize
        }
        
        // Store in both caches
        DownloadGroup.fileSizeCache[key] = total
        DownloadGroup.lastKnownGroupSizes[key] = total
        
        return total
    }
    
    /// Schedule a background calculation for when downloads complete
    private func scheduleBackgroundGroupSizeCalculation(cacheKey: String) {
        DispatchQueue.global(qos: .background).async {
            // Check if any assets are still being downloaded
            let stillHasActiveDownloads = self.assets.contains { asset in
                return asset.isCurrentlyBeingDownloaded()
            }
            
            if !stillHasActiveDownloads {
                // Calculate total size
                let total = self.assets.reduce(0) { runningTotal, asset in
                    return runningTotal + asset.calculateFileSizeInternal()
                }
                
                DispatchQueue.main.async {
                    // Update caches on main thread
                    DownloadGroup.fileSizeCache[cacheKey] = total
                    DownloadGroup.lastKnownGroupSizes[cacheKey] = total
                    
                    // Post a notification that group size has been updated
                    NotificationCenter.default.post(
                        name: NSNotification.Name("groupSizeUpdated"),
                        object: nil,
                        userInfo: ["groupId": self.id.uuidString]
                    )
                }
            }
        }
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
        lastKnownGroupSizes.removeAll()
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
            
            // Find poster URL - prioritize show-level posters over episode-specific ones
            let posterURL: URL? = {
                // First priority: Use dedicated showPosterURL if available
                if let showPosterURL = assets.compactMap({ $0.metadata?.showPosterURL }).first {
                    return showPosterURL
                }
                
                // Second priority: For anime/TV shows, look for consistent poster URLs that appear across multiple episodes
                // These are more likely to be show posters rather than episode-specific images
                if isShow && assets.count > 1 {
                    let posterURLs = assets.compactMap { $0.metadata?.posterURL }
                    let urlCounts = Dictionary(grouping: posterURLs, by: { $0 })
                    
                    // Find the most common poster URL (likely the show poster)
                    if let mostCommonPoster = urlCounts.max(by: { $0.value.count < $1.value.count })?.key {
                        return mostCommonPoster
                    }
                }
                
                // Fallback to first available poster
                return assets.compactMap { $0.metadata?.posterURL }.first
            }()
            
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
