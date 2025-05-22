//
//  ImagePrefetchManager.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import Foundation
import Kingfisher
import UIKit

/// Manager for image prefetching, caching, and optimization
class ImagePrefetchManager {
    static let shared = ImagePrefetchManager()
    
    // Prefetcher for batch prefetching images
    private let prefetcher = ImagePrefetcher(
        urls: [],
        options: [
            .processor(DownsamplingImageProcessor(size: CGSize(width: 100, height: 56))),
            .scaleFactor(UIScreen.main.scale),
            .cacheOriginalImage
        ]
    )
    
    // Keep track of what's already prefetched to avoid duplication
    private var prefetchedURLs = Set<URL>()
    private let prefetchQueue = DispatchQueue(label: "com.sora.imagePrefetch", qos: .utility)
    
    init() {
        // Set up KingfisherManager for optimal image loading
        ImageCache.default.memoryStorage.config.totalCostLimit = 300 * 1024 * 1024 // 300MB
        ImageCache.default.diskStorage.config.sizeLimit = 1000 * 1024 * 1024 // 1GB
        ImageDownloader.default.downloadTimeout = 15.0 // 15 seconds
    }
    
    /// Prefetch a batch of images
    func prefetchImages(_ urls: [String]) {
        prefetchQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Filter out already prefetched URLs and invalid URLs
            let urlObjects = urls.compactMap { URL(string: $0) }
                .filter { !self.prefetchedURLs.contains($0) }
            
            guard !urlObjects.isEmpty else { return }
            
            // Create a new prefetcher with the URLs and start it
            let newPrefetcher = ImagePrefetcher(
                urls: urlObjects,
                options: [
                    .processor(DownsamplingImageProcessor(size: CGSize(width: 100, height: 56))),
                    .scaleFactor(UIScreen.main.scale),
                    .cacheOriginalImage
                ]
            )
            newPrefetcher.start()
            
            // Track prefetched URLs
            urlObjects.forEach { self.prefetchedURLs.insert($0) }
        }
    }
    
    /// Prefetch a single image
    func prefetchImage(_ url: String) {
        guard let urlObject = URL(string: url),
              !prefetchedURLs.contains(urlObject) else {
            return
        }
        
        prefetchQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Create a new prefetcher with the URL and start it
            let newPrefetcher = ImagePrefetcher(
                urls: [urlObject],
                options: [
                    .processor(DownsamplingImageProcessor(size: CGSize(width: 100, height: 56))),
                    .scaleFactor(UIScreen.main.scale),
                    .cacheOriginalImage
                ]
            )
            newPrefetcher.start()
            
            // Track prefetched URL
            self.prefetchedURLs.insert(urlObject)
        }
    }
    
    /// Prefetch episode images for a batch of episodes
    func prefetchEpisodeImages(anilistId: Int, startEpisode: Int, count: Int) {
        prefetchQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Get metadata for episodes in the range
            for episodeNumber in startEpisode...(startEpisode + count) where episodeNumber > 0 {
                EpisodeMetadataManager.shared.fetchMetadata(anilistId: anilistId, episodeNumber: episodeNumber) { result in
                    switch result {
                    case .success(let metadata):
                        self.prefetchImage(metadata.imageUrl)
                    case .failure:
                        break
                    }
                }
            }
        }
    }
    
    /// Clear prefetch queue and stop any ongoing prefetch operations
    func cancelPrefetching() {
        prefetcher.stop()
    }
}

// MARK: - KFImage Extension
extension KFImage {
    /// Load an image with optimal settings for episode thumbnails
    static func optimizedEpisodeThumbnail(url: URL?) -> KFImage {
        return KFImage(url)
            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 100, height: 56)))
            .memoryCacheExpiration(.seconds(300))
            .cacheOriginalImage()
            .fade(duration: 0.25)
            .onProgress { _, _ in
                // Track progress if needed
            }
            .onSuccess { _ in
                // Success logger removed to reduce logs
            }
            .onFailure { error in
                Logger.shared.log("Failed to load image: \(error)", type: "Error")
            }
    }
} 