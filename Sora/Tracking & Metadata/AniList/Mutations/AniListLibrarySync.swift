//
//  AniListLibrarySync.swift
//  Sora
//
//  Created by Francesco on 15/08/26.
//

import Foundation

struct AniListSyncItem {
    let anilistId: Int
    let malId: Int?
    let title: String
    let coverImageUrl: String?
}

final class AniListLibrarySyncManager {
    static let shared = AniListLibrarySyncManager()
    private init() {}
    
    static let watchingCollectionName = "AniList Watching"
    static let planningCollectionName = "AniList Planning"
    
    private let apiURL = URL(string: "https://graphql.anilist.co")!
    private let viewerIdDefaultsKey = "aniListViewerId"
    
    func syncIfEnabled(libraryManager: LibraryManager) {
        guard UserDefaults.standard.bool(forKey: "aniListLibrarySyncEnabled") else { return }
        sync(libraryManager: libraryManager)
    }
    
    func sync(libraryManager: LibraryManager, completion: (() -> Void)? = nil) {
        guard AniListMutation().getTokenFromKeychain() != nil else {
            Logger.shared.log("AniList library sync skipped: no access token", type: "AniListSync")
            completion?()
            return
        }
        
        resolveViewerId { [weak self] viewerId in
            guard let self, let viewerId else {
                Logger.shared.log("AniList library sync failed: could not resolve viewer id", type: "AniListSync")
                completion?()
                return
            }
            
            let group = DispatchGroup()
            var watching: [AniListSyncItem] = []
            var planning: [AniListSyncItem] = []
            
            group.enter()
            self.fetchList(userId: viewerId, status: "CURRENT") { items in
                watching = items
                group.leave()
            }
            
            group.enter()
            self.fetchList(userId: viewerId, status: "PLANNING") { items in
                planning = items
                group.leave()
            }
            
            group.notify(queue: .main) {
                libraryManager.syncAniListItems(watching, toCollectionNamed: Self.watchingCollectionName)
                libraryManager.syncAniListItems(planning, toCollectionNamed: Self.planningCollectionName)
                Logger.shared.log(
                    "AniList library sync complete: \(watching.count) watching, \(planning.count) planning",
                    type: "AniListSync"
                )
                completion?()
            }
        }
    }
    
    // MARK: - Viewer id
    
    private func resolveViewerId(completion: @escaping (Int?) -> Void) {
        let cached = UserDefaults.standard.integer(forKey: viewerIdDefaultsKey)
        if cached != 0 {
            completion(cached)
            return
        }
        
        guard let token = AniListMutation().getTokenFromKeychain() else {
            completion(nil)
            return
        }
        
        let query = "query { Viewer { id } }"
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["query": query])
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self,
                  error == nil,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataDict = json["data"] as? [String: Any],
                  let viewer = dataDict["Viewer"] as? [String: Any],
                  let id = viewer["id"] as? Int
            else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            UserDefaults.standard.set(id, forKey: self.viewerIdDefaultsKey)
            DispatchQueue.main.async { completion(id) }
        }.resume()
    }
    
    private func fetchList(userId: Int, status: String, completion: @escaping ([AniListSyncItem]) -> Void) {
        guard let token = AniListMutation().getTokenFromKeychain() else {
            completion([])
            return
        }
        
        let query = """
        query ($userId: Int, $status: MediaListStatus) {
          MediaListCollection(userId: $userId, type: ANIME, status: $status) {
            lists {
              entries {
                media {
                  id
                  idMal
                  title { romaji english }
                  coverImage { large }
                }
              }
            }
          }
        }
        """
        let variables: [String: Any] = ["userId": userId, "status": status]
        let body: [String: Any] = ["query": query, "variables": variables]
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard error == nil,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataDict = json["data"] as? [String: Any],
                  let collection = dataDict["MediaListCollection"] as? [String: Any],
                  let lists = collection["lists"] as? [[String: Any]]
            else {
                Logger.shared.log("AniList \(status) list fetch failed", type: "AniListSync")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            var items: [AniListSyncItem] = []
            for list in lists {
                guard let entries = list["entries"] as? [[String: Any]] else { continue }
                for entry in entries {
                    guard let media = entry["media"] as? [String: Any],
                          let id = media["id"] as? Int else { continue }
                    let titleInfo = media["title"] as? [String: Any]
                    let title = (titleInfo?["english"] as? String) ?? (titleInfo?["romaji"] as? String) ?? "Unknown"
                    let cover = (media["coverImage"] as? [String: Any])?["large"] as? String
                    let malId = media["idMal"] as? Int
                    items.append(AniListSyncItem(anilistId: id, malId: malId, title: title, coverImageUrl: cover))
                }
            }
            DispatchQueue.main.async { completion(items) }
        }.resume()
    }
}
