//
//  ContinueReadingManager.swift
//  Sora
//
//  Created by paul on 26/06/25.
//

import Foundation

class ContinueReadingManager {
    static let shared = ContinueReadingManager()
    
    private let userDefaults = UserDefaults.standard
    private let continueReadingKey = "continueReadingItems"
    
    private init() {}
    
    func extractTitleFromURL(_ url: String) -> String? {
        guard let url = URL(string: url) else { return nil }
        
        let pathComponents = url.pathComponents
        
        for (index, component) in pathComponents.enumerated() {
            if component == "book" || component == "novel" {
                if index + 1 < pathComponents.count {
                    let bookTitle = pathComponents[index + 1]
                        .replacingOccurrences(of: "-", with: " ")
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized
                    
                    if !bookTitle.isEmpty {
                        return bookTitle
                    }
                }
            }
        }
        
        return nil
    }
    
    func fetchItems() -> [ContinueReadingItem] {
        guard let data = userDefaults.data(forKey: continueReadingKey) else {
            Logger.shared.log("No continue reading items found in UserDefaults", type: "Debug")
            return []
        }
        
        do {
            let items = try JSONDecoder().decode([ContinueReadingItem].self, from: data)
            Logger.shared.log("Fetched \(items.count) continue reading items", type: "Debug")
            
            for (index, item) in items.enumerated() {
                Logger.shared.log("Item \(index): \(item.mediaTitle), Image URL: \(item.imageUrl)", type: "Debug")
            }
            
            return items.sorted(by: { $0.lastReadDate > $1.lastReadDate })
        } catch {
            Logger.shared.log("Error decoding continue reading items: \(error)", type: "Error")
            return []
        }
    }
    
    func save(item: ContinueReadingItem) {
        var items = fetchItems()
        
        items.removeAll { $0.href == item.href }
        
        if item.progress >= 0.98 {
            userDefaults.set(item.progress, forKey: "readingProgress_\(item.href)")
            
            do {
                let data = try JSONEncoder().encode(items)
                userDefaults.set(data, forKey: continueReadingKey)
            } catch {
                Logger.shared.log("Error encoding continue reading items: \(error)", type: "Error")
            }
            return
        }
        
        var updatedItem = item
        if item.mediaTitle.contains("-") && item.mediaTitle.count >= 30 || item.mediaTitle.contains("Unknown") {
            if let betterTitle = extractTitleFromURL(item.href) {
                updatedItem = ContinueReadingItem(
                    id: item.id,
                    mediaTitle: betterTitle,
                    chapterTitle: item.chapterTitle,
                    chapterNumber: item.chapterNumber,
                    imageUrl: item.imageUrl,
                    href: item.href,
                    moduleId: item.moduleId,
                    progress: item.progress,
                    totalChapters: item.totalChapters,
                    lastReadDate: item.lastReadDate
                )
            }
        }
        
        // Log the incoming image URL for debugging
        Logger.shared.log("Incoming item image URL: \(updatedItem.imageUrl)", type: "Debug")
        
        // If no image URL is provided, use a default one
        if updatedItem.imageUrl.isEmpty {
            // Use a default novel cover image
            let defaultImageUrl = "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/novel_cover.jpg"
            updatedItem = ContinueReadingItem(
                id: updatedItem.id,
                mediaTitle: updatedItem.mediaTitle,
                chapterTitle: updatedItem.chapterTitle,
                chapterNumber: updatedItem.chapterNumber,
                imageUrl: defaultImageUrl,
                href: updatedItem.href,
                moduleId: updatedItem.moduleId,
                progress: updatedItem.progress,
                totalChapters: updatedItem.totalChapters,
                lastReadDate: updatedItem.lastReadDate
            )
            Logger.shared.log("Using default image URL: \(defaultImageUrl)", type: "Debug")
        }
        
        if !updatedItem.imageUrl.isEmpty {
            if URL(string: updatedItem.imageUrl) == nil {
                Logger.shared.log("Invalid image URL format: \(updatedItem.imageUrl)", type: "Warning")
                
                if let encodedUrl = updatedItem.imageUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let _ = URL(string: encodedUrl) {
                    updatedItem = ContinueReadingItem(
                        id: updatedItem.id,
                        mediaTitle: updatedItem.mediaTitle,
                        chapterTitle: updatedItem.chapterTitle,
                        chapterNumber: updatedItem.chapterNumber,
                        imageUrl: encodedUrl,
                        href: updatedItem.href,
                        moduleId: updatedItem.moduleId,
                        progress: updatedItem.progress,
                        totalChapters: updatedItem.totalChapters,
                        lastReadDate: updatedItem.lastReadDate
                    )
                    Logger.shared.log("Fixed image URL with encoding: \(encodedUrl)", type: "Debug")
                } else {
                    let defaultImageUrl = "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/novel_cover.jpg"
                    updatedItem = ContinueReadingItem(
                        id: updatedItem.id,
                        mediaTitle: updatedItem.mediaTitle,
                        chapterTitle: updatedItem.chapterTitle,
                        chapterNumber: updatedItem.chapterNumber,
                        imageUrl: defaultImageUrl,
                        href: updatedItem.href,
                        moduleId: updatedItem.moduleId,
                        progress: updatedItem.progress,
                        totalChapters: updatedItem.totalChapters,
                        lastReadDate: updatedItem.lastReadDate
                    )
                    Logger.shared.log("Using default image URL after encoding failed: \(defaultImageUrl)", type: "Debug")
                }
            }
        }
        
        Logger.shared.log("Saving item with image URL: \(updatedItem.imageUrl)", type: "Debug")
        
        items.append(updatedItem)
        
        if items.count > 20 {
            items = Array(items.sorted(by: { $0.lastReadDate > $1.lastReadDate }).prefix(20))
        }
        
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: continueReadingKey)
            Logger.shared.log("Successfully saved continue reading item", type: "Debug")
        } catch {
            Logger.shared.log("Error encoding continue reading items: \(error)", type: "Error")
        }
    }
    
    func remove(item: ContinueReadingItem) {
        var items = fetchItems()
        items.removeAll { $0.id == item.id }
        
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: continueReadingKey)
        } catch {
            Logger.shared.log("Error encoding continue reading items: \(error)", type: "Error")
        }
    }
    
    func updateProgress(for href: String, progress: Double) {
        var items = fetchItems()
        if let index = items.firstIndex(where: { $0.href == href }) {
            var updatedItem = items[index]
            
            if progress >= 0.98 {
                items.remove(at: index)
                userDefaults.set(progress, forKey: "readingProgress_\(href)")
                
                do {
                    let data = try JSONEncoder().encode(items)
                    userDefaults.set(data, forKey: continueReadingKey)
                } catch {
                    Logger.shared.log("Error encoding continue reading items: \(error)", type: "Error")
                }
                return
            }
            
            var mediaTitle = updatedItem.mediaTitle
            if mediaTitle.contains("-") && mediaTitle.count >= 30 || mediaTitle.contains("Unknown") {
                if let betterTitle = extractTitleFromURL(href) {
                    mediaTitle = betterTitle
                }
            }
            
            let newItem = ContinueReadingItem(
                id: updatedItem.id,
                mediaTitle: mediaTitle,
                chapterTitle: updatedItem.chapterTitle,
                chapterNumber: updatedItem.chapterNumber,
                imageUrl: updatedItem.imageUrl,
                href: updatedItem.href,
                moduleId: updatedItem.moduleId,
                progress: progress,
                totalChapters: updatedItem.totalChapters,
                lastReadDate: Date()
            )
            
            Logger.shared.log("Updating item with image URL: \(newItem.imageUrl)", type: "Debug")
            
            items[index] = newItem
            
            do {
                let data = try JSONEncoder().encode(items)
                userDefaults.set(data, forKey: continueReadingKey)
            } catch {
                Logger.shared.log("Error encoding continue reading items: \(error)", type: "Error")
            }
        }
    }
    
    func isChapterCompleted(href: String) -> Bool {
        let progress = UserDefaults.standard.double(forKey: "readingProgress_\(href)")
        if progress >= 0.98 {
            return true
        }
        
        let items = fetchItems()
        if let item = items.first(where: { $0.href == href }) {
            return item.progress >= 0.98
        }
        
        return false
    }
} 