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
        if item.progress >= 0.9 {
            remove(item: item)
            return
        }

        var items = fetchItems()

        items.removeAll { existing in
            existing.fullUrl == item.fullUrl &&
            existing.episodeNumber == item.episodeNumber &&
            existing.module.metadata.sourceName == item.module.metadata.sourceName
        }

        items.append(item)

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
