//
//  DownloadModels.swift
//  Sora
//
//  Created by Francesco on 29/04/25.
//

import Foundation
import AVFoundation

/// The current state of a download
enum DownloadState: String, Codable {
    case notDownloaded
    case downloading
    case paused
    case downloaded
    case failed
}

/// A model representing an active download
struct ActiveDownload: Identifiable, Codable, Equatable {
    let id: UUID
    let originalURL: URL
    var progress: Double
    var moduleType: String
    let episodeNumber: Int
    let title: String
    let imageURL: URL?
    let dateStarted: Date
    let episodeID: String // This will be the href or unique identifier for the episode
    
    // This is not encoded/decoded as it's transient
    var task: URLSessionTask? = nil
    
    enum CodingKeys: String, CodingKey {
        case id, originalURL, progress, moduleType, episodeNumber, title, imageURL, dateStarted, episodeID
    }
    
    static func == (lhs: ActiveDownload, rhs: ActiveDownload) -> Bool {
        lhs.id == rhs.id &&
        lhs.originalURL == rhs.originalURL &&
        lhs.moduleType == rhs.moduleType &&
        lhs.episodeNumber == rhs.episodeNumber &&
        lhs.title == rhs.title &&
        lhs.imageURL == rhs.imageURL &&
        lhs.dateStarted == rhs.dateStarted &&
        lhs.episodeID == rhs.episodeID
    }
}

/// A model representing a completely downloaded episode
struct DownloadedEpisode: Identifiable, Codable {
    let id: UUID
    var title: String
    let moduleType: String
    let episodeNumber: Int
    let downloadDate: Date
    let originalURL: URL
    let localURL: URL
    var fileSize: Int64?
    let imageURL: URL?
    let episodeID: String
    let aniListID: Int?
    
    init(id: UUID = UUID(), title: String, moduleType: String, episodeNumber: Int, 
         downloadDate: Date, originalURL: URL, localURL: URL, imageURL: URL?, 
         episodeID: String, aniListID: Int?) {
        self.id = id
        self.title = title
        self.moduleType = moduleType
        self.episodeNumber = episodeNumber
        self.downloadDate = downloadDate
        self.originalURL = originalURL
        self.localURL = localURL
        self.imageURL = imageURL
        self.episodeID = episodeID
        self.aniListID = aniListID
        self.fileSize = getFileSize()
    }
    
    func getFileSize() -> Int64? {
        do {
            let values = try localURL.resourceValues(forKeys: [.fileSizeKey])
            return Int64(values.fileSize ?? 0)
        } catch {
            return nil
        }
    }
}

/// A model representing the status and metadata of a downloadable episode
struct DownloadableEpisode: Identifiable, Equatable {
    let id: UUID = UUID()
    let episodeID: String  // Unique identifier (usually href)
    let title: String
    let moduleType: String
    let episodeNumber: Int
    let streamURL: URL
    let imageURL: URL?
    let aniListID: Int?
    var state: DownloadState = .notDownloaded
    var progress: Double = 0.0
    
    static func == (lhs: DownloadableEpisode, rhs: DownloadableEpisode) -> Bool {
        lhs.id == rhs.id &&
        lhs.episodeID == rhs.episodeID &&
        lhs.title == rhs.title &&
        lhs.moduleType == rhs.moduleType &&
        lhs.episodeNumber == rhs.episodeNumber &&
        lhs.streamURL == rhs.streamURL &&
        lhs.imageURL == rhs.imageURL &&
        lhs.aniListID == rhs.aniListID &&
        lhs.state == rhs.state &&
        lhs.progress == rhs.progress
    }
} 