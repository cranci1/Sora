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
    
    enum ExternalIDType {
        case imdb(String)
        case tmdb(Int)
        
        var dictionary: [String: Any] {
            switch self {
            case .imdb(let id):
                return ["imdb": id]
            case .tmdb(let id):
                return ["tmdb": id]
            }
        }
    }
    
    func markAsWatched(type: String, externalID: ExternalIDType, episodeNumber: Int? = nil, seasonNumber: Int? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        if let sendTraktUpdates = UserDefaults.standard.object(forKey: "sendTraktUpdates") as? Bool,
           sendTraktUpdates == false {
            return
        }
        
        guard let userToken = getTokenFromKeychain() else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Access token not found"])))
            return
        }
        
        let endpoint = "/sync/history"
        let body: [String: Any]
        
        switch type {
        case "movie":
            body = [
                "movies": [
                    [
                        "ids": externalID.dictionary
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
                        "ids": externalID.dictionary,
                        "seasons": [
                            [
                                "number": season,
                                "episodes": [
                                    ["number": episode]
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
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(TraktToken.clientID, forHTTPHeaderField: "trakt-api-key")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                      let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                      completion(.failure(NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Unexpected response or status code"])))
                      return
                  }
            
            Logger.shared.log("Successfully updated watch status on Trakt", type: "Debug")
            completion(.success(()))
        }
        
        task.resume()
    }
}
