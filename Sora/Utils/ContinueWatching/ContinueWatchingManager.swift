//
//  ContinueWatchingManager.swift
//  Sora
//
//  Created by Francesco on 14/02/25.
//

import SwiftUI

// TODO: filter continueWatchingItems by profile
class ContinueWatchingManager: ObservableObject {
    @Published var items: [ContinueWatchingItem] = []

    private var unfilteredItems: [ContinueWatchingItem] = []
    public var profile: Profile? = nil
    private let storageKey = "continueWatchingItems"

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleiCloudSync), name: .iCloudSyncDidComplete, object: nil)
    }

    public func updateProfile(_ newValue: Profile) {
        self.profile = newValue
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

        if let index = unfilteredItems.firstIndex(where: {
            $0.profileId == item.profileId &&
            $0.streamUrl == item.streamUrl &&
            $0.episodeNumber == item.episodeNumber }) {
            unfilteredItems[index] = item
        } else {
            unfilteredItems.append(item)
        }
        if let data = try? JSONEncoder().encode(unfilteredItems) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    func loadItems() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            unfilteredItems = (try? JSONDecoder().decode([ContinueWatchingItem].self, from: data)) ?? []

            items = unfilteredItems.filter({ item in
                if let itemProfileId = item.profileId,
                   let profileId = profile?.id {
                    // if both are present -> check equality
                    return itemProfileId == profileId
                } else {
                    // at least one is missing -> legacy items :S
                    return true
                }
            })
        } else {
            items = []
            unfilteredItems = []
        }
    }
    
    func remove(item: ContinueWatchingItem) {
        items.removeAll { $0.id == item.id && item.profileId == profile?.id }
        unfilteredItems.removeAll { $0.id == item.id && item.profileId == profile?.id }
        if let data = try? JSONEncoder().encode(unfilteredItems) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
