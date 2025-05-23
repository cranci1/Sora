//
//  MetadataCacheManager.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import Foundation
import SwiftUI

/// A class to manage episode metadata caching, both in-memory and on disk
class MetadataCacheManager {
    static let shared = MetadataCacheManager()
    
    // In-memory cache
    private let memoryCache = NSCache<NSString, NSData>()
    
    // File manager for disk operations
    private let fileManager = FileManager.default
    
    // Cache directory URL
    private var cacheDirectory: URL
    
    // Cache expiration - 7 days by default
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60
    
    // UserDefaults keys
    private let metadataCachingEnabledKey = "metadataCachingEnabled"
    private let memoryOnlyModeKey = "metadataMemoryOnlyCache" 
    private let lastCacheCleanupKey = "lastMetadataCacheCleanup"
    
    // Analytics counters
    private(set) var cacheHits: Int = 0
    private(set) var cacheMisses: Int = 0
    
    // MARK: - Public properties
    
    /// Whether metadata caching is enabled (persisted in UserDefaults)
    var isCachingEnabled: Bool {
        get {
            // Default to true if not set
            UserDefaults.standard.object(forKey: metadataCachingEnabledKey) == nil ? 
                true : UserDefaults.standard.bool(forKey: metadataCachingEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: metadataCachingEnabledKey)
        }
    }
    
    /// Whether to use memory-only mode (no disk caching)
    var isMemoryOnlyMode: Bool {
        get {
            UserDefaults.standard.bool(forKey: memoryOnlyModeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: memoryOnlyModeKey)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Set up cache directory
        do {
            let cachesDirectory = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            cacheDirectory = cachesDirectory.appendingPathComponent("EpisodeMetadata", isDirectory: true)
            
            // Create the directory if it doesn't exist
            if !fileManager.fileExists(atPath: cacheDirectory.path) {
                try fileManager.createDirectory(at: cacheDirectory, 
                                               withIntermediateDirectories: true, 
                                               attributes: nil)
            }
            
            // Set up memory cache
            memoryCache.name = "EpisodeMetadataCache"
            memoryCache.countLimit = 100  // Limit number of items in memory
            
            // Clean up old files if needed
            cleanupOldCacheFilesIfNeeded()
            
        } catch {
            Logger.shared.log("Failed to set up metadata cache directory: \(error)", type: "Error")
            // Fallback to temporary directory
            cacheDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("EpisodeMetadata")
        }
    }
    
    // MARK: - Public Methods
    
    /// Store metadata in the cache
    /// - Parameters:
    ///   - data: The metadata to cache
    ///   - key: The cache key (usually anilist_id + episode_number)
    func storeMetadata(_ data: Data, forKey key: String) {
        guard isCachingEnabled else { return }
        
        let keyString = key as NSString
        
        // Always store in memory cache
        memoryCache.setObject(data as NSData, forKey: keyString)
        
        // Store on disk if not in memory-only mode
        if !isMemoryOnlyMode {
            let fileURL = cacheDirectory.appendingPathComponent(key)
            
            DispatchQueue.global(qos: .background).async { [weak self] in
                do {
                    try data.write(to: fileURL)
                    
                    // Add timestamp as a file attribute instead of using extended attributes
                    let attributes: [FileAttributeKey: Any] = [
                        .creationDate: Date()
                    ]
                    try self?.fileManager.setAttributes(attributes, ofItemAtPath: fileURL.path)
                    
                    Logger.shared.log("Metadata cached for key: \(key)", type: "Debug")
                } catch {
                    Logger.shared.log("Failed to write metadata to disk: \(error)", type: "Error")
                }
            }
        }
    }
    
    /// Retrieve metadata from cache
    /// - Parameter key: The cache key
    /// - Returns: The cached metadata if available and not expired, nil otherwise
    func getMetadata(forKey key: String) -> Data? {
        guard isCachingEnabled else {
            return nil
        }
        
        let keyString = key as NSString
        
        // Try memory cache first
        if let cachedData = memoryCache.object(forKey: keyString) as Data? {
            return cachedData
        }
        
        // If not in memory and not in memory-only mode, try disk
        if !isMemoryOnlyMode {
            let fileURL = cacheDirectory.appendingPathComponent(key)
            
            do {
                // Check if file exists
                if fileManager.fileExists(atPath: fileURL.path) {
                    // Check if the file is not expired
                    if !isFileExpired(at: fileURL) {
                        let data = try Data(contentsOf: fileURL)
                        
                        // Store in memory cache for faster access next time
                        memoryCache.setObject(data as NSData, forKey: keyString)
                        
                        return data
                    } else {
                        // File is expired, remove it
                        try fileManager.removeItem(at: fileURL)
                    }
                }
            } catch {
                Logger.shared.log("Error accessing disk cache: \(error)", type: "Error")
            }
        }
        
        return nil
    }
    
    /// Clear all cached metadata
    func clearAllCache() {
        // Clear memory cache
        memoryCache.removeAllObjects()
        
        // Clear disk cache
        if !isMemoryOnlyMode {
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, 
                                                                  includingPropertiesForKeys: nil,
                                                                  options: .skipsHiddenFiles)
                
                for fileURL in fileURLs {
                    try fileManager.removeItem(at: fileURL)
                }
                
                Logger.shared.log("Cleared all metadata cache", type: "General")
            } catch {
                Logger.shared.log("Failed to clear disk cache: \(error)", type: "Error")
            }
        }
        
        // Reset analytics
        cacheHits = 0
        cacheMisses = 0
    }
    
    /// Clear expired cache entries
    func clearExpiredCache() {
        guard !isMemoryOnlyMode else { return }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, 
                                                              includingPropertiesForKeys: nil, 
                                                              options: .skipsHiddenFiles)
            
            var removedCount = 0
            
            for fileURL in fileURLs {
                if isFileExpired(at: fileURL) {
                    try fileManager.removeItem(at: fileURL)
                    removedCount += 1
                }
            }
            
            if removedCount > 0 {
                Logger.shared.log("Cleared \(removedCount) expired metadata cache items", type: "General")
            }
        } catch {
            Logger.shared.log("Failed to clear expired cache: \(error)", type: "Error")
        }
    }
    
    /// Get the total size of the cache on disk
    /// - Returns: Size in bytes
    func getCacheSize() -> Int64 {
        guard !isMemoryOnlyMode else { return 0 }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, 
                                                              includingPropertiesForKeys: [.fileSizeKey], 
                                                              options: .skipsHiddenFiles)
            
            return fileURLs.reduce(0) { result, url in
                do {
                    let attributes = try url.resourceValues(forKeys: [.fileSizeKey])
                    return result + Int64(attributes.fileSize ?? 0)
                } catch {
                    return result
                }
            }
        } catch {
            Logger.shared.log("Failed to calculate cache size: \(error)", type: "Error")
            return 0
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func isFileExpired(at url: URL) -> Bool {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let creationDate = attributes[.creationDate] as? Date {
                return Date().timeIntervalSince(creationDate) > maxCacheAge
            }
            return true // If can't determine age, consider it expired
        } catch {
            return true // If error reading attributes, consider it expired
        }
    }
    
    private func cleanupOldCacheFilesIfNeeded() {
        // Only run cleanup once a day
        let lastCleanupTime = UserDefaults.standard.double(forKey: lastCacheCleanupKey)
        let dayInSeconds: TimeInterval = 24 * 60 * 60
        
        if Date().timeIntervalSince1970 - lastCleanupTime > dayInSeconds {
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.clearExpiredCache()
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self?.lastCacheCleanupKey ?? "")
            }
        }
    }
} 