//
//  Modules.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import Foundation

struct ModuleMetadata: Codable, Hashable {
    let sourceName: String
    let author: Author
    let iconUrl: String
    let version: String
    let language: String
    let baseUrl: String
    let streamType: String
    let quality: String
    let searchBaseUrl: String
    let scriptUrl: String
    let asyncJS: Bool?
    let streamAsyncJS: Bool?
    let softsub: Bool?
    let multiStream: Bool?
    let multiSubs: Bool?
    let type: String?
    let novel: Bool?

    struct Author: Codable, Hashable {
        let name: String
        let icon: String
    }
}

struct ScrapingModule: Codable, Identifiable, Hashable {
    let id: UUID
    let metadata: ModuleMetadata
    let localPath: String
    let metadataUrl: String
    var isActive: Bool
    
    init(id: UUID = UUID(), metadata: ModuleMetadata, localPath: String, metadataUrl: String, isActive: Bool = false) {
        self.id = id
        self.metadata = metadata
        self.localPath = localPath
        self.metadataUrl = metadataUrl
        self.isActive = isActive
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ScrapingModule, rhs: ScrapingModule) -> Bool {
        lhs.id == rhs.id
    }
}
