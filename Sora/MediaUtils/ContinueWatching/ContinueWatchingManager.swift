//
//  ContinueWatchingManager.swift
//  Sora
//
//  Created by Francesco on 14/02/25.
//

import Foundation

class ContinueWatchingManager {
    static let shared = ContinueWatchingManager()
    private let storageKey = "continueWatchingItems"
    private let lastCleanupKey = "lastContinueWatchingCleanup"
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleiCloudSync), name: .iCloudSyncDidComplete, object: nil)
        performCleanupIfNeeded()
    }
    
    @objc private func handleiCloudSync() {
        NotificationCenter.default.post(name: .ContinueWatchingDidUpdate, object: nil)
    }
    
    private func performCleanupIfNeeded() {
        let lastCleanup = UserDefaults.standard.double(forKey: lastCleanupKey)
        let currentTime = Date().timeIntervalSince1970
        
        if currentTime - lastCleanup > 86400 {
            cleanupOldEpisodes()
            UserDefaults.standard.set(currentTime, forKey: lastCleanupKey)
        }
    }
    
    private func cleanupOldEpisodes() {
        var items = fetchItems()
        var itemsToRemove: Set<UUID> = []
        
        let groupedItems = Dictionary(grouping: items) { item in
            let title = item.mediaTitle.replacingOccurrences(of: "Episode \\d+.*$", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return title
        }
        
        for (_, showEpisodes) in groupedItems {
            let sortedEpisodes = showEpisodes.sorted { $0.episodeNumber < $1.episodeNumber }
            
            for i in 0..<sortedEpisodes.count - 1 {
                let currentEpisode = sortedEpisodes[i]
                let nextEpisode = sortedEpisodes[i + 1]
                
                let remainingTimePercentage = UserDefaults.standard.object(forKey: "remainingTimePercentage") != nil ? UserDefaults.standard.double(forKey: "remainingTimePercentage") : 90.0
                let threshold = (100.0 - remainingTimePercentage) / 100.0
                if currentEpisode.progress >= threshold && nextEpisode.episodeNumber > currentEpisode.episodeNumber {
                    itemsToRemove.insert(currentEpisode.id)
                }
            }
        }
        
        if !itemsToRemove.isEmpty {
            items.removeAll { itemsToRemove.contains($0.id) }
            if let data = try? JSONEncoder().encode(items) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
        }
    }
    
    func save(item: ContinueWatchingItem) {
        let lastKey = "lastPlayedTime_\(item.fullUrl)"
        let totalKey = "totalTime_\(item.fullUrl)"
        let lastPlayed = UserDefaults.standard.double(forKey: lastKey)
        let totalTime = UserDefaults.standard.double(forKey: totalKey)
        
        let actualProgress: Double
        if totalTime > 0 {
            actualProgress = min(max(lastPlayed / totalTime, 0), 1)
        } else {
            actualProgress = item.progress
            
            let remainingTimePercentage = UserDefaults.standard.object(forKey: "remainingTimePercentage") != nil ? UserDefaults.standard.double(forKey: "remainingTimePercentage") : 90.0
            let threshold = (100.0 - remainingTimePercentage) / 100.0
            if actualProgress >= threshold {
                remove(item: item)
                return
            }
            
            var updatedItem = item
            updatedItem.progress = actualProgress
            
            var items = fetchItems()
            
            let showTitle = item.mediaTitle.replacingOccurrences(of: "Episode \\d+.*$", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            items.removeAll { existingItem in
                let existingShowTitle = existingItem.mediaTitle.replacingOccurrences(of: "Episode \\d+.*$", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                let remainingTimePercentage = UserDefaults.standard.object(forKey: "remainingTimePercentage") != nil ? UserDefaults.standard.double(forKey: "remainingTimePercentage") : 90.0
                let threshold = (100.0 - remainingTimePercentage) / 100.0
                return showTitle == existingShowTitle &&
                existingItem.episodeNumber < item.episodeNumber &&
                existingItem.progress >= threshold
            }
            
            items.removeAll { existing in
                existing.fullUrl == item.fullUrl &&
                existing.episodeNumber == item.episodeNumber &&
                existing.module.metadata.sourceName == item.module.metadata.sourceName
            }
            
            items.append(updatedItem)
            
            if let data = try? JSONEncoder().encode(items) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
        }
    }
    
    func fetchItems() -> [ContinueWatchingItem] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let raw = try? JSONDecoder().decode([ContinueWatchingItem].self, from: data)
        else {
            return []
        }
        
        var seen = Set<String>()
        let unique = raw.reversed().filter { item in
            let key = "\(item.fullUrl)|\(item.module.metadata.sourceName)|\(item.episodeNumber)"
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }.reversed()
        
        return Array(unique)
    }
    
    func remove(item: ContinueWatchingItem) {
        var items = fetchItems()
        items.removeAll { $0.id == item.id }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
