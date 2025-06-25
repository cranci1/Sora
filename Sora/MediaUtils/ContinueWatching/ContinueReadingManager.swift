import Foundation

class ContinueReadingManager {
    static let shared = ContinueReadingManager()
    
    private let userDefaults = UserDefaults.standard
    private let continueReadingKey = "continueReadingItems"
    
    private init() {}
    
    // Extract title from URL if possible
    func extractTitleFromURL(_ url: String) -> String? {
        guard let url = URL(string: url) else { return nil }
        
        let pathComponents = url.pathComponents
        
        // Look for "book" or "novel" in the path
        for (index, component) in pathComponents.enumerated() {
            if component == "book" || component == "novel" {
                // The next component is likely the book title
                if index + 1 < pathComponents.count {
                    let bookTitle = pathComponents[index + 1]
                        .replacingOccurrences(of: "-", with: " ")
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized
                    
                    if !bookTitle.isEmpty {
                        Logger.shared.log("Extracted title from URL: \(bookTitle)", type: "Debug")
                        return bookTitle
                    }
                }
            }
        }
        
        return nil
    }
    
    func fetchItems() -> [ContinueReadingItem] {
        guard let data = userDefaults.data(forKey: continueReadingKey) else {
            Logger.shared.log("No continue reading data found in UserDefaults", type: "Debug")
            return []
        }
        
        do {
            let items = try JSONDecoder().decode([ContinueReadingItem].self, from: data)
            
            // Sort by most recent first
            let sortedItems = items.sorted(by: { $0.lastReadDate > $1.lastReadDate })
            
            // Log the sorted items
            for (index, item) in sortedItems.enumerated() {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short
                let dateString = dateFormatter.string(from: item.lastReadDate)
                Logger.shared.log("Item \(index): \(item.mediaTitle) - \(item.chapterTitle), date: \(dateString)", type: "Debug")
            }
            
            Logger.shared.log("Successfully decoded \(sortedItems.count) continue reading items", type: "Debug")
            return sortedItems
        } catch {
            Logger.shared.log("Error decoding continue reading items: \(error)", type: "Error")
            return []
        }
    }
    
    func save(item: ContinueReadingItem) {
        var items = fetchItems()
        
        // Remove existing item with the same href if exists
        items.removeAll { $0.href == item.href }
        
        // If the item is completed (progress >= 0.98), don't add it to the list
        if item.progress >= 0.98 {
            Logger.shared.log("Item is completed, not adding to continue reading: \(item.mediaTitle), chapter \(item.chapterTitle)", type: "Debug")
            
            // Still save the progress in UserDefaults
            userDefaults.set(item.progress, forKey: "readingProgress_\(item.href)")
            return
        }
        
        // Check if we need to improve the title
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
                Logger.shared.log("Improved title from \(item.mediaTitle) to \(betterTitle)", type: "Debug")
            }
        }
        
        // Add the new item
        items.append(updatedItem)
        
        // Keep only the most recent 20 items
        if items.count > 20 {
            items = Array(items.sorted(by: { $0.lastReadDate > $1.lastReadDate }).prefix(20))
        }
        
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: continueReadingKey)
            Logger.shared.log("Saved continue reading item: \(updatedItem.mediaTitle), chapter \(updatedItem.chapterTitle), progress \(updatedItem.progress)", type: "Debug")
            Logger.shared.log("Total continue reading items: \(items.count)", type: "Debug")
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
            Logger.shared.log("Error encoding continue reading items after removal: \(error)", type: "Error")
        }
    }
    
    func updateProgress(for href: String, progress: Double) {
        var items = fetchItems()
        if let index = items.firstIndex(where: { $0.href == href }) {
            var updatedItem = items[index]
            
            // Check if we need to improve the title
            var mediaTitle = updatedItem.mediaTitle
            if mediaTitle.contains("-") && mediaTitle.count >= 30 || mediaTitle.contains("Unknown") {
                if let betterTitle = extractTitleFromURL(href) {
                    mediaTitle = betterTitle
                    Logger.shared.log("Improved title from \(updatedItem.mediaTitle) to \(betterTitle) during progress update", type: "Debug")
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
                Logger.shared.log("Progress updated to \(progress)", type: "Debug")
            } catch {
                Logger.shared.log("Error encoding continue reading items after update: \(error)", type: "Error")
            }
        }
    }
    
    func isChapterCompleted(href: String) -> Bool {
        // Check stored progress first
        let progress = UserDefaults.standard.double(forKey: "readingProgress_\(href)")
        if progress >= 0.98 {
            return true
        }
        
        // Then check in the items
        let items = fetchItems()
        if let item = items.first(where: { $0.href == href }) {
            return item.progress >= 0.98
        }
        
        return false
    }
} 