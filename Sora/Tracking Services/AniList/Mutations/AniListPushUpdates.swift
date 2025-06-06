//
//  AniListPushUpdates.swift
//  Sulfur
//
//  Created by Francesco on 07/04/25.
//

import UIKit
import Security

class AniListMutation {
    let apiURL = URL(string: "https://graphql.anilist.co")!
    
    func getTokenFromKeychain() -> String? {
        let serviceName = "me.cranci.sora.AniListToken"
        let accountName = "AniListAccessToken"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let tokenData = item as? Data else {
            return nil
        }
        
        return String(data: tokenData, encoding: .utf8)
    }
    
    func updateAnimeProgress(
          animeId: Int,
          episodeNumber: Int,
          status: String = "CURRENT",
          completion: @escaping (Result<Void, Error>) -> Void
        ) {
          if let sendPushUpdates = UserDefaults.standard.object(forKey: "sendPushUpdates") as? Bool,
             sendPushUpdates == false {
              return
          }

          guard let userToken = getTokenFromKeychain() else {
              completion(.failure(NSError(
                domain: "",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Access token not found"]
              )))
              return
          }

          let query = """
          mutation ($mediaId: Int, $progress: Int, $status: MediaListStatus) {
            SaveMediaListEntry(mediaId: $mediaId, progress: $progress, status: $status) {
              id
              progress
              status
            }
          }
          """

          let variables: [String: Any] = [
            "mediaId": animeId,
            "progress": episodeNumber,
            "status": status
          ]
        
        let requestBody: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: []) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize JSON"])))
            return
        }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Unexpected response or status code"])))
                return
            }
            
            if let data = data {
                do {
                    _ = try JSONSerialization.jsonObject(with: data, options: [])
                    Logger.shared.log("Successfully updated anime progress", type: "Debug")
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
            }
        }
        
        task.resume()
    }
    
    func fetchMediaStatus(
      mediaId: Int,
      completion: @escaping (Result<String, Error>) -> Void
    ) {
      guard let token = getTokenFromKeychain() else {
        completion(.failure(NSError(
          domain: "", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Access token not found"]
        )))
        return
      }

      let query = """
      query ($mediaId: Int) {
        Media(id: $mediaId) {
          status
        }
      }
      """

      let vars = ["mediaId": mediaId]
      var req = URLRequest(url: URL(string: "https://graphql.anilist.co")!)
      req.httpMethod = "POST"
      req.addValue("application/json", forHTTPHeaderField: "Content-Type")
      req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      req.httpBody = try? JSONSerialization.data(
        withJSONObject: ["query": query, "variables": vars]
      )

      URLSession.shared.dataTask(with: req) { data, _, error in
        if let e = error { return completion(.failure(e)) }
        guard
          let d = data,
          let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
          let md = (json["data"] as? [String: Any])?["Media"] as? [String: Any],
          let status = md["status"] as? String
        else {
          return completion(.failure(NSError(
            domain: "", code: -2,
            userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
          )))
        }
        completion(.success(status))
      }.resume()
    }
    
    func fetchMalID(animeId: Int, completion: @escaping (Result<Int, Error>) -> Void) {
        let query = """
        query ($id: Int) {
          Media(id: $id) {
            idMal
          }
        }
        """
        let variables: [String: Any] = ["id": animeId]
        let requestBody: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: []) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize GraphQL request"])))
            return
        }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, resp, error in
            if let e = error {
                return completion(.failure(e))
            }
            guard let data = data,
                  let json = try? JSONDecoder().decode(AniListMediaResponse.self, from: data),
                  let mal = json.data.Media?.idMal else {
                      return completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode AniList response or idMal missing"])))
                  }
            completion(.success(mal))
        }.resume()
    }
    
    private struct AniListMediaResponse: Decodable {
        struct DataField: Decodable {
            struct Media: Decodable { let idMal: Int? }
            let Media: Media?
        }
        let data: DataField
    }
}

struct EpisodeMetadataInfo: Codable, Equatable {
    let title: [String: String]
    let imageUrl: String
    let anilistId: Int
    let episodeNumber: Int
}
