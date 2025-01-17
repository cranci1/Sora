//
//  LibraryManager.swift
//  Sora
//
//  Created by Francesco on 12/01/25.
//

import Foundation
import SwiftUI

struct LibraryItem: Codable, Identifiable {
    let id: UUID
    let title: String
    let imageUrl: String
    let href: String
    let moduleId: String
    let dateAdded: Date
    
    init(title: String, imageUrl: String, href: String, moduleId: String) {
        self.id = UUID()
        self.title = title
        self.imageUrl = imageUrl
        self.href = href
        self.moduleId = moduleId
        self.dateAdded = Date()
    }
}

class LibraryManager: ObservableObject {
    @Published var bookmarks: [LibraryItem] = []
    private let bookmarksKey = "bookmarkedItems"
    
    init() {
        loadBookmarks()
        Logger.shared.log("Started Sora", level: .info)
    }
    
    private func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: bookmarksKey),
           let decoded = try? JSONDecoder().decode([LibraryItem].self, from: data) {
            bookmarks = decoded
        }
    }
    
    private func saveBookmarks() {
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(encoded, forKey: bookmarksKey)
        }
    }
    
    func isBookmarked(href: String) -> Bool {
        bookmarks.contains { $0.href == href }
    }
    
    func toggleBookmark(title: String, imageUrl: String, href: String, moduleId: String) {
        if let index = bookmarks.firstIndex(where: { $0.href == href }) {
            bookmarks.remove(at: index)
        } else {
            let bookmark = LibraryItem(title: title, imageUrl: imageUrl, href: href, moduleId: moduleId)
            bookmarks.insert(bookmark, at: 0)
        }
        saveBookmarks()
    }
}
