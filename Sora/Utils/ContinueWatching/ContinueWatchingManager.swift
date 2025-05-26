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
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleiCloudSync), name: .iCloudSyncDidComplete, object: nil)
    }
    
    @objc private func handleiCloudSync() {
        NotificationCenter.default.post(name: .ContinueWatchingDidUpdate, object: nil)
    }
    
    func save(item: ContinueWatchingItem) {
        // Read the real playback times
        let lastKey  = "lastPlayedTime_\(item.fullUrl)"
        let totalKey = "totalTime_\(item.fullUrl)"
        let lastPlayed = UserDefaults.standard.double(forKey: lastKey)
        let totalTime  = UserDefaults.standard.double(forKey: totalKey)

        // Compute up-to-date progress
        let actualProgress: Double
        if totalTime > 0 {
            actualProgress = min(max(lastPlayed / totalTime, 0), 1)
        } else {
            actualProgress = item.progress
        }

        // If watched ≥ 90%, remove it
        if actualProgress >= 0.9 {
            remove(item: item)
            return
        }

        // Otherwise update progress and re-save
        var updatedItem = item
        updatedItem.progress = actualProgress

        var items = fetchItems()
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
