//
//  LibraryManager.swift
//  Sora
//
//  Created by Francesco on 12/01/25.
//

import SwiftUI

struct LibraryItem: Codable, Identifiable {
    let profileId: UUID?

    let id: UUID
    let title: String
    let imageUrl: String
    let href: String
    let moduleId: String
    let moduleName: String
    let dateAdded: Date
    
    init(profileId: UUID?, title: String, imageUrl: String, href: String, moduleId: String, moduleName: String) {
        self.profileId = profileId
        self.id = UUID()
        self.title = title
        self.imageUrl = imageUrl
        self.href = href
        self.moduleId = moduleId
        self.moduleName = moduleName
        self.dateAdded = Date()
    }
}

// TODO: filter bookmarks by profile
class LibraryManager: ObservableObject {
    public var profile: Profile? = nil

    @Published var bookmarks: [LibraryItem] = []
    private var unfilteredBookmarks: [LibraryItem] = []
    private let bookmarksKey = "bookmarkedItems"
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleiCloudSync), name: .iCloudSyncDidComplete, object: nil)
    }

    public func updateProfile(_ newValue: Profile) {
        self.profile = newValue
        loadBookmarks()
    }

    @objc private func handleiCloudSync() {
        DispatchQueue.main.async {
            self.loadBookmarks()
        }
    }
    
    func removeBookmark(item: LibraryItem) {
        if let index = bookmarks.firstIndex(where: { $0.id == item.id }) {
            unfilteredBookmarks.removeAll {
                $0.id == item.id &&
                $0.profileId == profile?.id
            }
            bookmarks.remove(at: index)

            Logger.shared.log("Removed series \(item.id) from bookmarks.",type: "Debug")
            saveBookmarks()
        }
    }
    
    private func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey) else {
            Logger.shared.log("No bookmarks data found in UserDefaults.", type: "Debug")
            return
        }

        do {
            unfilteredBookmarks = try JSONDecoder().decode([LibraryItem].self, from: data)
            bookmarks = unfilteredBookmarks.filter({ item in
                if let itemProfileId = item.profileId,
                   let profileId = profile?.id {
                    // if both are present -> check equality
                    return itemProfileId == profileId
                } else {
                    // at least one is missing -> legacy bookmarks :S
                    return true
                }
            })
        } catch {
            Logger.shared.log("Failed to decode bookmarks: \(error.localizedDescription)", type: "Error")
        }
    }
    
    private func saveBookmarks() {
        do {
            let encoded = try JSONEncoder().encode(unfilteredBookmarks)
            UserDefaults.standard.set(encoded, forKey: bookmarksKey)
        } catch {
            Logger.shared.log("Failed to encode bookmarks: \(error.localizedDescription)", type: "Error")
        }
    }
    
    func isBookmarked(href: String, moduleName: String) -> Bool {
        bookmarks.contains { $0.href == href }
    }
    
    func toggleBookmark(title: String, imageUrl: String, href: String, moduleId: String, moduleName: String) {
        if let index = bookmarks.firstIndex(where: { $0.href == href }) {
            unfilteredBookmarks.removeAll {
                $0.href == href &&
                $0.profileId == profile?.id
            }
            bookmarks.remove(at: index)
        } else {
            let bookmark = LibraryItem(profileId: profile?.id, title: title, imageUrl: imageUrl, href: href, moduleId: moduleId, moduleName: moduleName)
            unfilteredBookmarks.insert(bookmark, at: 0)
            bookmarks.insert(bookmark, at: 0)
        }
        saveBookmarks()
    }
}
