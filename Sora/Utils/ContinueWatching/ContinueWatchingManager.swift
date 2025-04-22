//
//  ContinueWatchingManager.swift
//  Sora
//
//  Created by Francesco on 14/02/25.
//

import SwiftUI

class ContinueWatchingManager: ObservableObject {
    var userDefaultsSuite = UserDefaults.standard
    @Published var items: [ContinueWatchingItem] = []
    private let storageKey = "continueWatchingItems"

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleiCloudSync), name: .iCloudSyncDidComplete, object: nil)
    }

    public func updateProfileSuite(_ newSuite: UserDefaults) {
        userDefaultsSuite = newSuite
        loadItems()
    }

    @objc private func handleiCloudSync() {
        NotificationCenter.default.post(name: .ContinueWatchingDidUpdate, object: nil)
    }
    
    func save(item: ContinueWatchingItem) {
        if item.progress >= 0.9 {
            remove(item: item)
            return
        }

        if let index = items.firstIndex(where: {
            $0.streamUrl == item.streamUrl &&
            $0.episodeNumber == item.episodeNumber }) {
            items[index] = item
        } else {
            items.append(item)
        }

        if let data = try? JSONEncoder().encode(items) {
            userDefaultsSuite.set(data, forKey: storageKey)
        }
    }
    
    func loadItems() {
        if let data = userDefaultsSuite.data(forKey: storageKey),
        let parsedItems = try? JSONDecoder().decode([ContinueWatchingItem].self, from: data) {
            items = parsedItems
        } else {
            items = []
        }
    }
    
    func remove(item: ContinueWatchingItem) {
        items.removeAll { $0.id == item.id }
        if let data = try? JSONEncoder().encode(items) {
            userDefaultsSuite.set(data, forKey: storageKey)
        }
    }
}
