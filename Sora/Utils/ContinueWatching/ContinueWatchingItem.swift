//
//  ContinueWatchingItem.swift
//  Sora
//
//  Created by Francesco on 14/02/25.
//

import Foundation

struct ContinueWatchingItem: Codable, Identifiable {
    let id: UUID
    let imageUrl: String
    let episodeNumber: Int
    let mediaTitle: String
    var progress: Double
    let streamUrl: String
    let fullUrl: String
    let subtitles: String?
    let aniListID: Int?
    let module: ScrapingModule
    let headers: [String:String]?
}
