//
//  LibraryManager.swift
//  Sora
//
//  Created by Francesco on 12/01/25.
//

import Foundation
import SwiftUI
import NukeUI
import Nuke

struct BookmarkCollection: Codable, Identifiable {
    let id: UUID
    let name: String
    var bookmarks: [LibraryItem]
    let dateCreated: Date
    
    init(name: String, bookmarks: [LibraryItem] = []) {
        self.id = UUID()
        self.name = name
        self.bookmarks = bookmarks
        self.dateCreated = Date()
    }
}

struct LibraryItem: Codable, Identifiable {
    let id: UUID
    var title: String
    var imageUrl: String
    var href: String
    var moduleId: String
    var moduleName: String
    let dateAdded: Date
    var anilistId: Int? = nil
    var isAniListPlaceholder: Bool = false
    
    init(
        title: String,
        imageUrl: String,
        href: String,
        moduleId: String,
        moduleName: String,
        anilistId: Int? = nil,
        isAniListPlaceholder: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.imageUrl = imageUrl
        self.href = href
        self.moduleId = moduleId
        self.moduleName = moduleName
        self.dateAdded = Date()
        self.anilistId = anilistId
        self.isAniListPlaceholder = isAniListPlaceholder
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, imageUrl, href, moduleId, moduleName, dateAdded, anilistId, isAniListPlaceholder
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        href = try container.decode(String.self, forKey: .href)
        moduleId = try container.decode(String.self, forKey: .moduleId)
        moduleName = try container.decode(String.self, forKey: .moduleName)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        anilistId = try container.decodeIfPresent(Int.self, forKey: .anilistId)
        isAniListPlaceholder = try container.decodeIfPresent(Bool.self, forKey: .isAniListPlaceholder) ?? false
    }
}

class LibraryManager: ObservableObject {
    @Published var collections: [BookmarkCollection] = []
    @Published var isShowingCollectionPicker: Bool = false
    @Published var bookmarkToAdd: LibraryItem?
    
    private let collectionsKey = "bookmarkCollections"
    private let oldBookmarksKey = "bookmarkedItems"
    
    init() {
        migrateOldBookmarks()
        loadCollections()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleiCloudSync), name: .iCloudSyncDidComplete, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleModuleRemoval), name: .moduleRemoved, object: nil)
    }
    
    @objc private func handleiCloudSync() {
        DispatchQueue.main.async {
            self.loadCollections()
        }
    }
    
    @objc private func handleModuleRemoval(_ notification: Notification) {
        if let moduleId = notification.object as? String {
            cleanupBookmarksForModule(moduleId: moduleId)
        }
    }
    
    private func cleanupBookmarksForModule(moduleId: String) {
        var didChange = false
        
        for (collectionIndex, collection) in collections.enumerated() {
            let originalCount = collection.bookmarks.count
            collections[collectionIndex].bookmarks.removeAll { $0.moduleId == moduleId }
            
            if collections[collectionIndex].bookmarks.count != originalCount {
                didChange = true
            }
        }
        
        if didChange {
            ImagePipeline.shared.cache.removeAll()
            saveCollections()
        }
    }
    
    private func migrateOldBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: oldBookmarksKey) else {
            return
        }
        
        do {
            let oldBookmarks = try JSONDecoder().decode([LibraryItem].self, from: data)
            if !oldBookmarks.isEmpty {
                if let existingIndex = collections.firstIndex(where: { $0.name == "Old Bookmarks" }) {
                    for bookmark in oldBookmarks {
                        if !collections[existingIndex].bookmarks.contains(where: { $0.href == bookmark.href }) {
                            collections[existingIndex].bookmarks.insert(bookmark, at: 0)
                        }
                    }
                } else {
                    let oldCollection = BookmarkCollection(name: "Old Bookmarks", bookmarks: oldBookmarks)
                    collections.append(oldCollection)
                }
                saveCollections()
            }
            
            UserDefaults.standard.removeObject(forKey: oldBookmarksKey)
        } catch {
            Logger.shared.log("Failed to migrate old bookmarks: \(error)", type: "Error")
        }
    }
    
    private func loadCollections() {
        guard let data = UserDefaults.standard.data(forKey: collectionsKey) else {
            Logger.shared.log("No collections data found in UserDefaults.", type: "Debug")
            return
        }
        
        do {
            collections = try JSONDecoder().decode([BookmarkCollection].self, from: data)
        } catch {
            Logger.shared.log("Failed to decode collections: \(error.localizedDescription)", type: "Error")
        }
    }
    
    private func saveCollections() {
        do {
            let encoded = try JSONEncoder().encode(collections)
            UserDefaults.standard.set(encoded, forKey: collectionsKey)
        } catch {
            Logger.shared.log("Failed to save collections: \(error)", type: "Error")
        }
    }
    
    func createCollection(name: String) {
        let newCollection = BookmarkCollection(name: name)
        collections.append(newCollection)
        saveCollections()
    }
    
    func deleteCollection(id: UUID) {
        collections.removeAll { $0.id == id }
        saveCollections()
    }
    
    func addBookmarkToCollection(bookmark: LibraryItem, collectionId: UUID) {
        if let index = collections.firstIndex(where: { $0.id == collectionId }) {
            if !collections[index].bookmarks.contains(where: { $0.href == bookmark.href }) {
                collections[index].bookmarks.insert(bookmark, at: 0)
                saveCollections()
            }
        }
    }
    
    func removeBookmarkFromCollection(bookmarkId: UUID, collectionId: UUID) {
        if let collectionIndex = collections.firstIndex(where: { $0.id == collectionId }) {
            collections[collectionIndex].bookmarks.removeAll { $0.id == bookmarkId }
            saveCollections()
        }
    }
    
    func isBookmarked(href: String, moduleName: String) -> Bool {
        for collection in collections {
            if collection.bookmarks.contains(where: { $0.href == href }) {
                return true
            }
        }
        return false
    }
    
    func toggleBookmark(title: String, imageUrl: String, href: String, moduleId: String, moduleName: String) {
        for (collectionIndex, collection) in collections.enumerated() {
            if let bookmarkIndex = collection.bookmarks.firstIndex(where: { $0.href == href }) {
                collections[collectionIndex].bookmarks.remove(at: bookmarkIndex)
                saveCollections()
                return
            }
        }
        
        let bookmark = LibraryItem(title: title, imageUrl: imageUrl, href: href, moduleId: moduleId, moduleName: moduleName)
        bookmarkToAdd = bookmark
        isShowingCollectionPicker = true
    }
    
    func renameCollection(id: UUID, newName: String) {
        if let index = collections.firstIndex(where: { $0.id == id }) {
            var updated = collections[index]
            updated = BookmarkCollection(name: newName, bookmarks: updated.bookmarks)
            collections[index] = BookmarkCollection(name: newName, bookmarks: updated.bookmarks)
            saveCollections()
        }
    }
    
    // MARK: - AniList sync
    
    func getOrCreateCollection(named name: String) -> UUID {
        if let existing = collections.first(where: { $0.name == name }) {
            return existing.id
        }
        let newCollection = BookmarkCollection(name: name)
        collections.append(newCollection)
        saveCollections()
        return newCollection.id
    }
    
    func syncAniListItems(_ items: [AniListSyncItem], toCollectionNamed name: String) {
        let collectionId = getOrCreateCollection(named: name)
        guard let index = collections.firstIndex(where: { $0.id == collectionId }) else { return }
        
        let existingIds = Set(collections[index].bookmarks.compactMap { $0.anilistId })
        var didChange = false
        
        for item in items where !existingIds.contains(item.anilistId) {
            let placeholder = LibraryItem(
                title: item.title,
                imageUrl: item.coverImageUrl ?? "",
                href: "anilist-unmatched://\(item.anilistId)",
                moduleId: "",
                moduleName: "Unmatched",
                anilistId: item.anilistId,
                isAniListPlaceholder: true
            )
            collections[index].bookmarks.insert(placeholder, at: 0)
            didChange = true
        }
        
        if didChange { saveCollections() }
    }
    
    func resolveAniListPlaceholder(
        itemId: UUID,
        collectionId: UUID,
        matchedHref: String,
        moduleId: String,
        moduleName: String,
        matchedTitle: String,
        matchedImageUrl: String
    ) {
        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionId }),
              let itemIndex = collections[collectionIndex].bookmarks.firstIndex(where: { $0.id == itemId })
        else { return }
        
        var item = collections[collectionIndex].bookmarks[itemIndex]
        let anilistId = item.anilistId
        
        item.href = matchedHref
        item.moduleId = moduleId
        item.moduleName = moduleName
        item.title = matchedTitle
        item.imageUrl = matchedImageUrl
        item.isAniListPlaceholder = false
        
        collections[collectionIndex].bookmarks[itemIndex] = item
        saveCollections()
        
        if let anilistId {
            UserDefaults.standard.set(anilistId, forKey: "custom_anilist_id_\(matchedHref)")
        }
    }
}
