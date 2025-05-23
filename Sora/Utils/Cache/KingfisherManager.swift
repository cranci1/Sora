//
//  KingfisherManager.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import Foundation
import Kingfisher
import SwiftUI

/// Manages Kingfisher image caching configuration
class KingfisherCacheManager {
    static let shared = KingfisherCacheManager()
    
    /// Maximum disk cache size (default 500MB)
    private let maxDiskCacheSize: UInt = 500 * 1024 * 1024
    
    /// Maximum cache age (default 7 days)
    private let maxCacheAgeInDays: TimeInterval = 7
    
    /// UserDefaults keys
    private let imageCachingEnabledKey = "imageCachingEnabled"
    
    /// Whether image caching is enabled
    var isCachingEnabled: Bool {
        get {
            // Default to true if not set
            UserDefaults.standard.object(forKey: imageCachingEnabledKey) == nil ? 
                true : UserDefaults.standard.bool(forKey: imageCachingEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: imageCachingEnabledKey)
            configureKingfisher()
        }
    }
    
    private init() {
        configureKingfisher()
    }
    
    /// Configure Kingfisher with appropriate caching settings
    func configureKingfisher() {
        let cache = ImageCache.default
        
        // Set disk cache size limit and expiration
        cache.diskStorage.config.sizeLimit = isCachingEnabled ? maxDiskCacheSize : 0
        cache.diskStorage.config.expiration = isCachingEnabled ? 
            .days(Int(maxCacheAgeInDays)) : .seconds(1)  // 1 second means effectively disabled
        
        // Set memory cache size
        cache.memoryStorage.config.totalCostLimit = isCachingEnabled ? 
            30 * 1024 * 1024 : 0  // 30MB memory cache when enabled
            
        // Configure clean interval
        cache.memoryStorage.config.cleanInterval = 60  // Clean memory every 60 seconds
        
        // Configure retry strategy
        KingfisherManager.shared.downloader.downloadTimeout = 15.0  // 15 second timeout
        
        Logger.shared.log("Configured Kingfisher cache. Enabled: \(isCachingEnabled)", type: "Debug")
    }
    
    /// Clear all cached images
    func clearCache(completion: (() -> Void)? = nil) {
        KingfisherManager.shared.cache.clearMemoryCache()
        KingfisherManager.shared.cache.clearDiskCache {
            Logger.shared.log("Cleared Kingfisher image cache", type: "General")
            completion?()
        }
    }
    
    /// Calculate current cache size
    /// - Parameter completion: Closure to call with cache size in bytes
    func calculateCacheSize(completion: @escaping (UInt) -> Void) {
        KingfisherManager.shared.cache.calculateDiskStorageSize { result in
            switch result {
            case .success(let size):
                completion(size)
            case .failure(let error):
                Logger.shared.log("Failed to calculate image cache size: \(error)", type: "Error")
                completion(0)
            }
        }
    }
    
    /// Convert cache size to user-friendly string
    /// - Parameter sizeInBytes: Size in bytes
    /// - Returns: Formatted string (e.g., "5.2 MB")
    static func formatCacheSize(_ sizeInBytes: UInt) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(sizeInBytes))
    }
} 