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
            return []
        }
        
        do {
            let items = try JSONDecoder().decode([ContinueReadingItem].self, from: data)
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
        
        items.append(updatedItem)
        
        if items.count > 20 {
            items = Array(items.sorted(by: { $0.lastReadDate > $1.lastReadDate }).prefix(20))
        }
        
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: continueReadingKey)
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