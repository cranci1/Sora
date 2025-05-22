//
//  EpisodeMetadataManager.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
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
    
    // Add retry configuration properties
    private let maxRetryAttempts = 3
    private let initialBackoffDelay: TimeInterval = 1.0 // in seconds
    private var currentRetryAttempts: [String: Int] = [:] // Track retry attempts by cache key
    
    // MARK: - Public Interface
    
    /// Fetch metadata for a single episode
    /// - Parameters:
    ///   - anilistId: The Anilist ID of the anime
    ///   - episodeNumber: The episode number to fetch
    ///   - completion: Callback with the result
    func fetchMetadata(anilistId: Int, episodeNumber: Int, completion: @escaping (Result<EpisodeMetadataInfo, Error>) -> Void) {
        let cacheKey = "anilist_\(anilistId)_episode_\(episodeNumber)"
        
        // Check if we already have this metadata
        if let existingStatus = metadataCache[cacheKey] {
            switch existingStatus {
            case .fetched(let metadata):
                // Return cached data immediately
                completion(.success(metadata))
                return
                
            case .fetching:
                // Already fetching, will be notified via publisher
                // Set up a listener for when this request completes
                waitForRequest(cacheKey: cacheKey, completion: completion)
                return
                
            case .failed:
                // Previous attempt failed, try again
                break
                
            case .notRequested:
                // Should not happen but continue to fetch
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
            
            completion(.success(metadataInfo))
            return
        }
        
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
        
        // Reset retry attempts if this is a new fetch
        if currentRetryAttempts[cacheKey] == nil {
            currentRetryAttempts[cacheKey] = 0
        }
        
        // Create API request
        guard let url = URL(string: "https://api.ani.zip/mappings?anilist_id=\(anilistId)") else {
            let error = NSError(domain: "com.sora.metadata", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            DispatchQueue.main.async {
                self.metadataCache[cacheKey] = .failed(error)
            }
            completion(.failure(error))
            return
        }
        
        Logger.shared.log("Fetching metadata for episode \(episodeNumber) from network", type: "Debug")
        
        // Create publisher for the request
        let publisher = URLSession.custom.dataTaskPublisher(for: url)
            .subscribe(on: fetchQueue)
            .tryMap { [weak self] data, response -> EpisodeMetadataInfo in
                guard let self = self else {
                    throw NSError(domain: "com.sora.metadata", code: 4, 
                                  userInfo: [NSLocalizedDescriptionKey: "Manager instance released"])
                }
                
                // Validate response
                guard let httpResponse = response as? HTTPURLResponse, 
                      httpResponse.statusCode == 200 else {
                    throw NSError(domain: "com.sora.metadata", code: 2, 
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                // Parse JSON
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any] else {
                    throw NSError(domain: "com.sora.metadata", code: 3, 
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid data format"])
                }
                
                // Check for episodes object
                guard let episodes = json["episodes"] as? [String: Any] else {
                    Logger.shared.log("Missing 'episodes' object in response for anilistId: \(anilistId)", type: "Error")
                    throw NSError(domain: "com.sora.metadata", code: 3, 
                                 userInfo: [NSLocalizedDescriptionKey: "Missing episodes object in response"])
                }
                
                // Check if episode exists in response
                let episodeKey = "\(episodeNumber)"
                guard let episodeDetails = episodes[episodeKey] as? [String: Any] else {
                    Logger.shared.log("Episode \(episodeNumber) not found in response for anilistId: \(anilistId)", type: "Error")
                    throw NSError(domain: "com.sora.metadata", code: 5, 
                                 userInfo: [NSLocalizedDescriptionKey: "Episode \(episodeNumber) not found in response"])
                }
                
                // Extract available fields, log if they're missing
                var title: [String: String] = [:]
                var image: String = ""
                var missingFields: [String] = []
                
                // Try to get title
                if let titleData = episodeDetails["title"] as? [String: String] {
                    title = titleData
                    
                    // Check if we have valid title values
                    if title.isEmpty || title.values.allSatisfy({ $0.isEmpty }) {
                        missingFields.append("title (all values empty)")
                    }
                } else {
                    missingFields.append("title")
                    // Create default empty title dictionary
                    title = ["en": "Episode \(episodeNumber)"]
                }
                
                // Try to get image
                if let imageUrl = episodeDetails["image"] as? String {
                    image = imageUrl
                    
                    if imageUrl.isEmpty {
                        missingFields.append("image (empty string)")
                    }
                } else {
                    missingFields.append("image")
                    // Use a default placeholder image
                    image = "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner1.png"
                }
                
                // Log missing fields but continue processing
                if !missingFields.isEmpty {
                    Logger.shared.log("Episode \(episodeNumber) for anilistId \(anilistId) missing fields: \(missingFields.joined(separator: ", "))", type: "Warning")
                }
                
                // Create metadata object with whatever we have
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
                
                // Reset retry count on success (even with missing fields)
                self.currentRetryAttempts.removeValue(forKey: cacheKey)
                
                return metadataInfo
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                // Handle completion
                guard let self = self else { return }
                
                switch result {
                case .finished:
                    break
                case .failure(let error):
                    // Handle retry logic
                    var shouldRetry = false
                    let currentAttempt = self.currentRetryAttempts[cacheKey] ?? 0
                    
                    // Check if we should retry based on the error and attempt count
                    if currentAttempt < self.maxRetryAttempts {
                        // Increment attempt counter
                        let nextAttempt = currentAttempt + 1
                        self.currentRetryAttempts[cacheKey] = nextAttempt
                        
                        // Calculate backoff delay using exponential backoff
                        let backoffDelay = self.initialBackoffDelay * pow(2.0, Double(currentAttempt))
                        
                        Logger.shared.log("Metadata fetch failed, retrying (attempt \(nextAttempt)/\(self.maxRetryAttempts)) in \(backoffDelay) seconds", type: "Debug")
                        
                        // Schedule retry after backoff delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + backoffDelay) {
                            // Remove the current request before retrying
                            self.activeRequests.removeValue(forKey: cacheKey)
                            self.performFetch(anilistId: anilistId, episodeNumber: episodeNumber, cacheKey: cacheKey, completion: completion)
                        }
                        shouldRetry = true
                    } else {
                        // Max retries reached
                        Logger.shared.log("Metadata fetch failed after \(self.maxRetryAttempts) attempts: \(error.localizedDescription)", type: "Error")
                        self.currentRetryAttempts.removeValue(forKey: cacheKey)
                    }
                    
                    if !shouldRetry {
                        // Update cache with error
                        self.metadataCache[cacheKey] = .failed(error)
                        completion(.failure(error))
                        // Remove from active requests
                        self.activeRequests.removeValue(forKey: cacheKey)
                    }
                }
            }, receiveValue: { [weak self] metadataInfo in
                // Update cache with result
                self?.metadataCache[cacheKey] = .fetched(metadataInfo)
                completion(.success(metadataInfo))
                
                // Remove from active requests
                self?.activeRequests.removeValue(forKey: cacheKey)
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
        
        // Reset retry attempts if this is a new fetch
        if currentRetryAttempts[batchCacheKey] == nil {
            currentRetryAttempts[batchCacheKey] = 0
        }
        
        // Create publisher for the request
        let publisher = URLSession.custom.dataTaskPublisher(for: url)
            .subscribe(on: fetchQueue)
            .tryMap { [weak self] data, response -> [Int: EpisodeMetadataInfo] in
                guard let self = self else {
                    throw NSError(domain: "com.sora.metadata", code: 4, 
                                  userInfo: [NSLocalizedDescriptionKey: "Manager instance released"])
                }
                
                // Validate response
                guard let httpResponse = response as? HTTPURLResponse, 
                      httpResponse.statusCode == 200 else {
                    throw NSError(domain: "com.sora.metadata", code: 2, 
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                // Parse JSON
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any] else {
                    throw NSError(domain: "com.sora.metadata", code: 3, 
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid data format"])
                }
                
                guard let episodes = json["episodes"] as? [String: Any] else {
                    Logger.shared.log("Missing 'episodes' object in response for anilistId: \(anilistId)", type: "Error")
                    throw NSError(domain: "com.sora.metadata", code: 3, 
                                 userInfo: [NSLocalizedDescriptionKey: "Missing episodes object in response"])
                }
                
                // Check if we have at least one requested episode
                let hasAnyRequestedEpisode = episodeNumbers.contains { episodeNumber in
                    return episodes["\(episodeNumber)"] != nil
                }
                
                if !hasAnyRequestedEpisode {
                    Logger.shared.log("None of the requested episodes were found for anilistId: \(anilistId)", type: "Error")
                    throw NSError(domain: "com.sora.metadata", code: 5, 
                                 userInfo: [NSLocalizedDescriptionKey: "None of the requested episodes were found"])
                }
                
                // Process each requested episode
                var results: [Int: EpisodeMetadataInfo] = [:]
                var missingEpisodes: [Int] = []
                var episodesWithMissingFields: [String] = []
                
                for episodeNumber in episodeNumbers {
                    let episodeKey = "\(episodeNumber)"
                    
                    // Check if this episode exists in the response
                    if let episodeDetails = episodes[episodeKey] as? [String: Any] {
                        var title: [String: String] = [:]
                        var image: String = ""
                        var missingFields: [String] = []
                        
                        // Try to get title
                        if let titleData = episodeDetails["title"] as? [String: String] {
                            title = titleData
                            
                            // Check if we have valid title values
                            if title.isEmpty || title.values.allSatisfy({ $0.isEmpty }) {
                                missingFields.append("title (all values empty)")
                            }
                        } else {
                            missingFields.append("title")
                            // Create default empty title dictionary
                            title = ["en": "Episode \(episodeNumber)"]
                        }
                        
                        // Try to get image
                        if let imageUrl = episodeDetails["image"] as? String {
                            image = imageUrl
                            
                            if imageUrl.isEmpty {
                                missingFields.append("image (empty string)")
                            }
                        } else {
                            missingFields.append("image")
                            // Use a default placeholder image
                            image = "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner1.png"
                        }
                        
                        // Log if we're missing any fields
                        if !missingFields.isEmpty {
                            episodesWithMissingFields.append("Episode \(episodeNumber): missing \(missingFields.joined(separator: ", "))")
                        }
                        
                        // Create metadata object with whatever we have
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
                    } else {
                        missingEpisodes.append(episodeNumber)
                    }
                }
                
                // Log information about missing episodes
                if !missingEpisodes.isEmpty {
                    Logger.shared.log("Episodes not found in response: \(missingEpisodes.map { String($0) }.joined(separator: ", "))", type: "Warning")
                }
                
                // Log information about episodes with missing fields
                if !episodesWithMissingFields.isEmpty {
                    Logger.shared.log("Episodes with missing fields: \(episodesWithMissingFields.joined(separator: "; "))", type: "Warning")
                }
                
                // If we didn't get data for all requested episodes but got some, consider it a partial success
                if results.count < episodeNumbers.count && results.count > 0 {
                    Logger.shared.log("Partial data received: \(results.count)/\(episodeNumbers.count) episodes", type: "Warning")
                }
                
                // If we didn't get any valid results, throw an error to trigger retry
                if results.isEmpty {
                    throw NSError(domain: "com.sora.metadata", code: 7, 
                                 userInfo: [NSLocalizedDescriptionKey: "No valid episode data found in response"])
                }
                
                // Reset retry count on success (even partial)
                self.currentRetryAttempts.removeValue(forKey: batchCacheKey)
                
                return results
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                // Handle completion
                guard let self = self else { return }
                
                switch result {
                case .finished:
                    break
                case .failure(let error):
                    // Handle retry logic
                    var shouldRetry = false
                    let currentAttempt = self.currentRetryAttempts[batchCacheKey] ?? 0
                    
                    // Check if we should retry based on the error and attempt count
                    if currentAttempt < self.maxRetryAttempts {
                        // Increment attempt counter
                        let nextAttempt = currentAttempt + 1
                        self.currentRetryAttempts[batchCacheKey] = nextAttempt
                        
                        // Calculate backoff delay using exponential backoff
                        let backoffDelay = self.initialBackoffDelay * pow(2.0, Double(currentAttempt))
                        
                        Logger.shared.log("Batch fetch failed, retrying (attempt \(nextAttempt)/\(self.maxRetryAttempts)) in \(backoffDelay) seconds", type: "Debug")
                        
                        // Schedule retry after backoff delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + backoffDelay) {
                            // Remove the current request before retrying
                            self.activeRequests.removeValue(forKey: batchCacheKey)
                            self.fetchBatchFromNetwork(anilistId: anilistId, episodeNumbers: episodeNumbers)
                        }
                        shouldRetry = true
                    } else {
                        // Max retries reached
                        Logger.shared.log("Batch fetch failed after \(self.maxRetryAttempts) attempts: \(error.localizedDescription)", type: "Error")
                        self.currentRetryAttempts.removeValue(forKey: batchCacheKey)
                        
                        // Update all requested episodes with error
                        for episodeNumber in episodeNumbers {
                            let cacheKey = "anilist_\(anilistId)_episode_\(episodeNumber)"
                            self.metadataCache[cacheKey] = .failed(error)
                        }
                    }
                    
                    if !shouldRetry {
                        // Remove from active requests
                        self.activeRequests.removeValue(forKey: batchCacheKey)
                    }
                }
            }, receiveValue: { [weak self] results in
                // Update cache with results
                for (episodeNumber, metadataInfo) in results {
                    let cacheKey = "anilist_\(anilistId)_episode_\(episodeNumber)"
                    self?.metadataCache[cacheKey] = .fetched(metadataInfo)
                }
                
                // Log the results
                Logger.shared.log("Batch fetch completed with \(results.count) episodes", type: "Debug")
                
                // Remove from active requests
                self?.activeRequests.removeValue(forKey: batchCacheKey)
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