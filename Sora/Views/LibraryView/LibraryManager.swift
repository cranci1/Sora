//
//  LibraryManager.swift
//  Sora
//
//  Created by Francesco on 12/01/25.
//

import Foundation
import SwiftUI

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
    let title: String
    let imageUrl: String
    let href: String
    let moduleId: String
    let moduleName: String
    let dateAdded: Date
    
    init(title: String, imageUrl: String, href: String, moduleId: String, moduleName: String) {
        self.id = UUID()
        self.title = title
        self.imageUrl = imageUrl
        self.href = href
        self.moduleId = moduleId
        self.moduleName = moduleName
        self.dateAdded = Date()
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
    }
    
    @objc private func handleiCloudSync() {
        DispatchQueue.main.async {
            self.loadCollections()
        }
    }
    
    private func migrateOldBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: oldBookmarksKey) else {
            return
        }
        
        do {
            let oldBookmarks = try JSONDecoder().decode([LibraryItem].self, from: data)
            if !oldBookmarks.isEmpty {
                // Check if "Old Bookmarks" collection already exists
                if let existingIndex = collections.firstIndex(where: { $0.name == "Old Bookmarks" }) {
                    // Add new bookmarks to existing collection, avoiding duplicates
                    for bookmark in oldBookmarks {
                        if !collections[existingIndex].bookmarks.contains(where: { $0.href == bookmark.href }) {
                            collections[existingIndex].bookmarks.insert(bookmark, at: 0)
                        }
                    }
                } else {
                    // Create new "Old Bookmarks" collection
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
}
