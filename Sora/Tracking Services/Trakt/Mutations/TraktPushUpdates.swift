//
//  TraktPushUpdates.swift
//  Sulfur
//
//  Created by Francesco on 13/04/25.
//

import UIKit
import Security

class TraktMutation {
    let apiURL = URL(string: "https://api.trakt.tv")!
    
    func getTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: TraktToken.serviceName,
            kSecAttrAccount as String: TraktToken.accessTokenKey,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let tokenData = item as? Data,
              let token = String(data: tokenData, encoding: .utf8) else {
                  return nil
              }
        return token
    }
    
    func markAsWatched(type: String, tmdbID: Int, episodeNumber: Int? = nil, seasonNumber: Int? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        if let sendTraktUpdates = UserDefaults.standard.object(forKey: "sendTraktUpdates") as? Bool,
           sendTraktUpdates == false {
            return
        }
        
        guard let userToken = getTokenFromKeychain() else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Access token not found"])))
            Logger.shared.log("Trakt Access token not found", type: "Error")
            return
        }
        
        let endpoint = "/sync/history"
        let watchedAt = ISO8601DateFormatter().string(from: Date())
        let body: [String: Any]
        
        switch type {
        case "movie":
            body = [
                "movies": [
                    [
                        "ids": ["tmdb": tmdbID],
                        "watched_at": watchedAt
                    ]
                ]
            ]
            
        case "episode":
            guard let episode = episodeNumber, let season = seasonNumber else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing episode or season number"])))
                return
            }
            
            body = [
                "shows": [
                    [
                        "ids": ["tmdb": tmdbID],
                        "seasons": [
                            [
                                "number": season,
                                "episodes": [
                                    [
                                        "number": episode,
                                        "watched_at": watchedAt
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
            
        default:
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid content type"])))
            return
        }
        
        var request = URLRequest(url: apiURL.appendingPathComponent(endpoint))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(TraktToken.clientID, forHTTPHeaderField: "trakt-api-key")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted])
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])))
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    Logger.shared.log("Trakt API Response: \(responseString)", type: "Debug")
                }
                Logger.shared.log("Successfully updated watch status on Trakt", type: "Debug")
                completion(.success(()))
            } else {
                var errorMessage = "Unexpected status code: \(httpResponse.statusCode)"
                if let data = data,
                   let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? String {
                    errorMessage = error
                }
                completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            }
        }
        
        task.resume()
    }
}
