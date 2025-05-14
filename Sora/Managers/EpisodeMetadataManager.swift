//
//  EpisodeMetadataManager.swift
//  Sora
//
//  Created by AI Assistant on 18/12/24.
//

import Foundation
import Combine

/// A model representing episode metadata
struct EpisodeMetadataInfo: Codable, Equatable {
    let title: [String: String]
    let imageUrl: String
    let anilistId: Int
    let episodeNumber: Int
    
    var cacheKey: String {
        return "anilist_\(anilistId)_episode_\(episodeNumber)"
    }
}

/// Status of a metadata fetch request
enum MetadataFetchStatus {
    case notRequested
    case fetching
    case fetched(EpisodeMetadataInfo)
    case failed(Error)
}

/// Central manager for fetching, caching, and prefetching episode metadata
class EpisodeMetadataManager: ObservableObject {
    static let shared = EpisodeMetadataManager()
    
    private init() {
        // Initialize any resources here
        Logger.shared.log("EpisodeMetadataManager initialized", type: "Info")
    }
    
    // Published properties that trigger UI updates
    @Published private var metadataCache: [String: MetadataFetchStatus] = [:]
    
    // In-flight requests to prevent duplicate API calls
    private var activeRequests: [String: AnyCancellable] = [:]
    
    // Queue for managing concurrent requests
    private let fetchQueue = DispatchQueue(label: "com.sora.metadataFetch", qos: .userInitiated, attributes: .concurrent)
    
    // MARK: - Public Interface
    
    /// Fetch metadata for a single episode
    /// - Parameters:
    ///   - anilistId: The Anilist ID of the anime
    ///   - episodeNumber: The episode number to fetch
    ///   - completion: Callback with the result
    func fetchMetadata(anilistId: Int, episodeNumber: Int, completion: @escaping (Result<EpisodeMetadataInfo, Error>) -> Void) {
        let cacheKey = "anilist_\(anilistId)_episode_\(episodeNumber)"
        
        // Start tracking request
        trackFetchStart(anilistId: anilistId, episodeNumber: episodeNumber)
        
        // Check if we already have this metadata
        if let existingStatus = metadataCache[cacheKey] {
            switch existingStatus {
            case .fetched(let metadata):
                // Return cached data immediately
                Logger.shared.log("Returning cached metadata for episode \(episodeNumber)", type: "Debug")
                trackCacheHit()
                trackFetchEnd(anilistId: anilistId, episodeNumber: episodeNumber)
                completion(.success(metadata))
                return
                
            case .fetching:
                // Already fetching, will be notified via publisher
                Logger.shared.log("Request for episode \(episodeNumber) already in progress", type: "Debug")
                // Set up a listener for when this request completes
                waitForRequest(cacheKey: cacheKey, completion: completion)
                return
                
            case .failed:
                // Previous attempt failed, try again
                trackCacheMiss()
                break
                
            case .notRequested:
                // Should not happen but continue to fetch
                trackCacheMiss()
                break
            }
        }
        
        // Check persistent cache
        if let cachedData = MetadataCacheManager.shared.getMetadata(forKey: cacheKey),
           let metadata = EpisodeMetadata.fromData(cachedData) {
            
            let metadataInfo = EpisodeMetadataInfo(
                title: metadata.title,
                imageUrl: metadata.imageUrl,
                anilistId: anilistId,
                episodeNumber: episodeNumber
            )
            
            // Update memory cache
            DispatchQueue.main.async {
                self.metadataCache[cacheKey] = .fetched(metadataInfo)
            }
            
            trackCacheHit()
            trackFetchEnd(anilistId: anilistId, episodeNumber: episodeNumber)
            
            Logger.shared.log("Loaded episode \(episodeNumber) metadata from persistent cache", type: "Debug")
            completion(.success(metadataInfo))
            return
        }
        
        // Track cache miss since we need to fetch from network
        trackCacheMiss()
        
        // Need to fetch from network
        DispatchQueue.main.async {
            self.metadataCache[cacheKey] = .fetching
        }
        
        performFetch(anilistId: anilistId, episodeNumber: episodeNumber, cacheKey: cacheKey, completion: completion)
    }
    
    /// Fetch metadata for multiple episodes in batch
    /// - Parameters:
    ///   - anilistId: The Anilist ID of the anime
    ///   - episodeNumbers: Array of episode numbers to fetch
    func batchFetchMetadata(anilistId: Int, episodeNumbers: [Int]) {
        // First check which episodes we need to fetch
        let episodesToFetch = episodeNumbers.filter { episodeNumber in
            let cacheKey = "anilist_\(anilistId)_episode_\(episodeNumber)"
            if let status = metadataCache[cacheKey] {
                switch status {
                case .fetched, .fetching:
                    return false
                default:
                    return true
                }
            }
            return true
        }
        
        guard !episodesToFetch.isEmpty else {
            Logger.shared.log("No new episodes to fetch in batch", type: "Debug")
            return
        }
        
        // Mark all as fetching
        for episodeNumber in episodesToFetch {
            let cacheKey = "anilist_\(anilistId)_episode_\(episodeNumber)"
            DispatchQueue.main.async {
                self.metadataCache[cacheKey] = .fetching
            }
        }
        
        // Perform batch fetch
        fetchBatchFromNetwork(anilistId: anilistId, episodeNumbers: episodesToFetch)
    }
    
    /// Prefetch metadata for a range of episodes
    /// - Parameters:
    ///   - anilistId: The Anilist ID of the anime
    ///   - startEpisode: The starting episode number
    ///   - count: How many episodes to prefetch
    func prefetchMetadata(anilistId: Int, startEpisode: Int, count: Int = 5) {
        let episodeNumbers = Array(startEpisode..<(startEpisode + count))
        batchFetchMetadata(anilistId: anilistId, episodeNumbers: episodeNumbers)
    }
    
    /// Get metadata for an episode (non-blocking, returns immediately from cache)
    /// - Parameters:
    ///   - anilistId: The Anilist ID of the anime
    ///   - episodeNumber: The episode number
    /// - Returns: The metadata fetch status
    func getMetadataStatus(anilistId: Int, episodeNumber: Int) -> MetadataFetchStatus {
        let cacheKey = "anilist_\(anilistId)_episode_\(episodeNumber)"
        return metadataCache[cacheKey] ?? .notRequested
    }
    
    // MARK: - Private Methods
    
    private func performFetch(anilistId: Int, episodeNumber: Int, cacheKey: String, completion: @escaping (Result<EpisodeMetadataInfo, Error>) -> Void) {
        // Check if there's already an active request for this metadata
        if activeRequests[cacheKey] != nil {
            // Already fetching, wait for it to complete
            waitForRequest(cacheKey: cacheKey, completion: completion)
            return
        }
        
        // Create API request
        guard let url = URL(string: "https://api.ani.zip/mappings?anilist_id=\(anilistId)") else {
            let error = NSError(domain: "com.sora.metadata", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            DispatchQueue.main.async {
                self.metadataCache[cacheKey] = .failed(error)
            }
            trackFetchEnd(anilistId: anilistId, episodeNumber: episodeNumber)
            completion(.failure(error))
            return
        }
        
        Logger.shared.log("Fetching metadata for episode \(episodeNumber) from network", type: "Debug")
        
        // Create publisher for the request
        let publisher = URLSession.custom.dataTaskPublisher(for: url)
            .subscribe(on: fetchQueue)
            .tryMap { data, response -> EpisodeMetadataInfo in
                // Validate response
                guard let httpResponse = response as? HTTPURLResponse, 
                      httpResponse.statusCode == 200 else {
                    throw NSError(domain: "com.sora.metadata", code: 2, 
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                // Parse JSON
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any],
                      let episodes = json["episodes"] as? [String: Any],
                      let episodeDetails = episodes["\(episodeNumber)"] as? [String: Any],
                      let title = episodeDetails["title"] as? [String: String],
                      let image = episodeDetails["image"] as? String else {
                    throw NSError(domain: "com.sora.metadata", code: 3, 
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid data format"])
                }
                
                // Create metadata object
                let metadataInfo = EpisodeMetadataInfo(
                    title: title,
                    imageUrl: image,
                    anilistId: anilistId,
                    episodeNumber: episodeNumber
                )
                
                // Cache the metadata
                if MetadataCacheManager.shared.isCachingEnabled {
                    let metadata = EpisodeMetadata(
                        title: title,
                        imageUrl: image,
                        anilistId: anilistId,
                        episodeNumber: episodeNumber
                    )
                    
                    if let metadataData = metadata.toData() {
                        MetadataCacheManager.shared.storeMetadata(
                            metadataData,
                            forKey: cacheKey
                        )
                        Logger.shared.log("Cached metadata for episode \(episodeNumber)", type: "Debug")
                    }
                }
                
                return metadataInfo
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                // Handle completion
                switch result {
                case .finished:
                    break
                case .failure(let error):
                    // Update cache with error
                    self?.metadataCache[cacheKey] = .failed(error)
                    self?.trackFetchEnd(anilistId: anilistId, episodeNumber: episodeNumber)
                    completion(.failure(error))
                }
                // Remove from active requests
                self?.activeRequests.removeValue(forKey: cacheKey)
            }, receiveValue: { [weak self] metadataInfo in
                // Update cache with result
                self?.metadataCache[cacheKey] = .fetched(metadataInfo)
                self?.trackFetchEnd(anilistId: anilistId, episodeNumber: episodeNumber)
                completion(.success(metadataInfo))
            })
        
        // Store publisher in active requests
        activeRequests[cacheKey] = publisher
    }
    
    private func fetchBatchFromNetwork(anilistId: Int, episodeNumbers: [Int]) {
        // This API returns all episodes for a show in one call, so we only need one request
        guard let url = URL(string: "https://api.ani.zip/mappings?anilist_id=\(anilistId)") else {
            Logger.shared.log("Invalid URL for batch fetch", type: "Error")
            return
        }
        
        Logger.shared.log("Batch fetching \(episodeNumbers.count) episodes from network", type: "Debug")
        
        let batchCacheKey = "batch_\(anilistId)_\(episodeNumbers.map { String($0) }.joined(separator: "_"))"
        
        // Create publisher for the request
        let publisher = URLSession.custom.dataTaskPublisher(for: url)
            .subscribe(on: fetchQueue)
            .tryMap { data, response -> [Int: EpisodeMetadataInfo] in
                // Validate response
                guard let httpResponse = response as? HTTPURLResponse, 
                      httpResponse.statusCode == 200 else {
                    throw NSError(domain: "com.sora.metadata", code: 2, 
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                // Parse JSON
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any],
                      let episodes = json["episodes"] as? [String: Any] else {
                    throw NSError(domain: "com.sora.metadata", code: 3, 
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid data format"])
                }
                
                // Process each requested episode
                var results: [Int: EpisodeMetadataInfo] = [:]
                
                for episodeNumber in episodeNumbers {
                    if let episodeDetails = episodes["\(episodeNumber)"] as? [String: Any],
                       let title = episodeDetails["title"] as? [String: String],
                       let image = episodeDetails["image"] as? String {
                        
                        // Create metadata object
                        let metadataInfo = EpisodeMetadataInfo(
                            title: title,
                            imageUrl: image,
                            anilistId: anilistId,
                            episodeNumber: episodeNumber
                        )
                        
                        results[episodeNumber] = metadataInfo
                        
                        // Cache the metadata
                        if MetadataCacheManager.shared.isCachingEnabled {
                            let metadata = EpisodeMetadata(
                                title: title,
                                imageUrl: image,
                                anilistId: anilistId,
                                episodeNumber: episodeNumber
                            )
                            
                            let cacheKey = "anilist_\(anilistId)_episode_\(episodeNumber)"
                            if let metadataData = metadata.toData() {
                                MetadataCacheManager.shared.storeMetadata(
                                    metadataData,
                                    forKey: cacheKey
                                )
                            }
                        }
                    }
                }
                
                return results
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                // Handle completion
                switch result {
                case .finished:
                    break
                case .failure(let error):
                    Logger.shared.log("Batch fetch failed: \(error.localizedDescription)", type: "Error")
                    
                    // Update all requested episodes with error
                    for episodeNumber in episodeNumbers {
                        let cacheKey = "anilist_\(anilistId)_episode_\(episodeNumber)"
                        self?.metadataCache[cacheKey] = .failed(error)
                    }
                }
                // Remove from active requests
                self?.activeRequests.removeValue(forKey: batchCacheKey)
            }, receiveValue: { [weak self] results in
                // Update cache with results
                for (episodeNumber, metadataInfo) in results {
                    let cacheKey = "anilist_\(anilistId)_episode_\(episodeNumber)"
                    self?.metadataCache[cacheKey] = .fetched(metadataInfo)
                }
                
                // Log the results
                Logger.shared.log("Batch fetch completed with \(results.count) episodes", type: "Debug")
            })
        
        // Store publisher in active requests
        activeRequests[batchCacheKey] = publisher
    }
    
    private func waitForRequest(cacheKey: String, completion: @escaping (Result<EpisodeMetadataInfo, Error>) -> Void) {
        // Set up a timer to check the cache periodically
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if let status = self.metadataCache[cacheKey] {
                switch status {
                case .fetched(let metadata):
                    // Request completed successfully
                    timer.invalidate()
                    completion(.success(metadata))
                case .failed(let error):
                    // Request failed
                    timer.invalidate()
                    completion(.failure(error))
                case .fetching, .notRequested:
                    // Still in progress
                    break
                }
            }
        }
        
        // Ensure timer fires even when scrolling
        RunLoop.current.add(timer, forMode: .common)
    }
}

// Extension to EpisodeMetadata for integration with the new manager
extension EpisodeMetadata {
    func toData() -> Data? {
        // Convert to EpisodeMetadataInfo first
        let info = EpisodeMetadataInfo(
            title: self.title,
            imageUrl: self.imageUrl,
            anilistId: self.anilistId,
            episodeNumber: self.episodeNumber
        )
        
        // Then encode to Data
        return try? JSONEncoder().encode(info)
    }
    
    static func fromData(_ data: Data) -> EpisodeMetadata? {
        guard let info = try? JSONDecoder().decode(EpisodeMetadataInfo.self, from: data) else {
            return nil
        }
        
        return EpisodeMetadata(
            title: info.title,
            imageUrl: info.imageUrl,
            anilistId: info.anilistId,
            episodeNumber: info.episodeNumber
        )
    }
} 