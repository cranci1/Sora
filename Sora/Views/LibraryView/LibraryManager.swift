//
//  LibraryManager.swift
//  Sora
//
//  Created by Francesco on 12/01/25.
//

import SwiftUI

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
    var userDefaultsSuite = UserDefaults.standard
    @Published var bookmarks: [LibraryItem] = []
    private let bookmarksKey = "bookmarkedItems"
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleiCloudSync), name: .iCloudSyncDidComplete, object: nil)
    }

    public func updateProfileSuite(_ newSuite: UserDefaults) {
        userDefaultsSuite = newSuite
        loadBookmarks()
    }

    @objc private func handleiCloudSync() {
        DispatchQueue.main.async {
            self.loadBookmarks()
        }
    }
    
    func removeBookmark(item: LibraryItem) {
        if let index = bookmarks.firstIndex(where: { $0.id == item.id }) {
            bookmarks.remove(at: index)

            Logger.shared.log("Removed series \(item.id) from bookmarks.",type: "Debug")
            saveBookmarks()
        }
    }
    
    private func loadBookmarks() {
        guard let data = userDefaultsSuite.data(forKey: bookmarksKey) else {
            Logger.shared.log("No bookmarks data found in UserDefaults.", type: "Debug")
            bookmarks = []
            return
        }

        do {
            bookmarks = try JSONDecoder().decode([LibraryItem].self, from: data)
        } catch {
            Logger.shared.log("Failed to decode bookmarks: \(error.localizedDescription)", type: "Error")
            bookmarks = []
        }
    }
    
    private func saveBookmarks() {
        do {
            let encoded = try JSONEncoder().encode(bookmarks)
            userDefaultsSuite.set(encoded, forKey: bookmarksKey)
        } catch {
            Logger.shared.log("Failed to encode bookmarks: \(error.localizedDescription)", type: "Error")
        }
    }
    
    func isBookmarked(href: String, moduleName: String) -> Bool {
        bookmarks.contains { $0.href == href }
    }
    
    func toggleBookmark(title: String, imageUrl: String, href: String, moduleId: String, moduleName: String) {
        if let index = bookmarks.firstIndex(where: { $0.href == href }) {
            bookmarks.remove(at: index)
        } else {
            let bookmark = LibraryItem(title: title, imageUrl: imageUrl, href: href, moduleId: moduleId, moduleName: moduleName)
            bookmarks.insert(bookmark, at: 0)
        }
        saveBookmarks()
    }
}
