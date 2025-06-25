import Foundation

struct ContinueReadingItem: Identifiable, Codable {
    let id: UUID
    let mediaTitle: String
    let chapterTitle: String
    let chapterNumber: Int
    let imageUrl: String
    let href: String
    let moduleId: String
    let progress: Double
    let totalChapters: Int
    let lastReadDate: Date
    
    init(
        id: UUID = UUID(),
        mediaTitle: String,
        chapterTitle: String,
        chapterNumber: Int,
        imageUrl: String,
        href: String,
        moduleId: String,
        progress: Double = 0.0,
        totalChapters: Int = 0,
        lastReadDate: Date = Date()
    ) {
        self.id = id
        self.mediaTitle = mediaTitle
        self.chapterTitle = chapterTitle
        self.chapterNumber = chapterNumber
        self.imageUrl = imageUrl
        self.href = href
        self.moduleId = moduleId
        self.progress = progress
        self.totalChapters = totalChapters
        self.lastReadDate = lastReadDate
    }
} 