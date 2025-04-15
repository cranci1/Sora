//
//  Trakt-Token.swift
//  Sulfur
//
//  Created by Francesco on 13/04/25.
//

import UIKit
import Security

class TraktToken {
    static let clientID = "6ec81bf19deb80fdfa25652eef101576ca6aaa0dc016d36079b2de413d71c369"
    static let clientSecret = "17cd92f71da3be9d755e2d8a6506fb3c3ecee19a247a6f0120ce2fb1f359850b"
    static let redirectURI = "sora://trakt"
    
    static let tokenEndpoint = "https://api.trakt.tv/oauth/token"
    static let serviceName = "me.cranci.sora.TraktToken"
    static let accessTokenKey = "TraktAccessToken"
    static let refreshTokenKey = "TraktRefreshToken"
    
    static let authSuccessNotification = Notification.Name("TraktAuthenticationSuccess")
    static let authFailureNotification = Notification.Name("TraktAuthenticationFailure")
    
    private static func saveToKeychain(key: String, data: String) -> Bool {
        let tokenData = data.data(using: .utf8)!
        
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: tokenData
        ]
        
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }
    
    static func exchangeAuthorizationCodeForToken(code: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: tokenEndpoint) else {
            Logger.shared.log("Invalid token endpoint URL", type: "Error")
            handleFailure(error: "Invalid token endpoint URL", completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let bodyData: [String: Any] = [
            "code": code,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]
        
        processTokenRequest(request: request, bodyData: bodyData, completion: completion)
    }
    
    static func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = getRefreshToken() else {
            handleFailure(error: "No refresh token available", completion: completion)
            return
        }
        
        guard let url = URL(string: tokenEndpoint) else {
            handleFailure(error: "Invalid token endpoint URL", completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let bodyData: [String: Any] = [
            "refresh_token": refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "refresh_token"
        ]
        
        processTokenRequest(request: request, bodyData: bodyData, completion: completion)
    }
    
    private static func processTokenRequest(request: URLRequest, bodyData: [String: Any], completion: @escaping (Bool) -> Void) {
        var request = request
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyData)
        } catch {
            handleFailure(error: "Failed to create request body", completion: completion)
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    handleFailure(error: error.localizedDescription, completion: completion)
                    return
                }
                
                guard let data = data else {
                    handleFailure(error: "No data received", completion: completion)
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let accessToken = json["access_token"] as? String,
                           let refreshToken = json["refresh_token"] as? String {
                            
                            let accessSuccess = saveToKeychain(key: accessTokenKey, data: accessToken)
                            let refreshSuccess = saveToKeychain(key: refreshTokenKey, data: refreshToken)
                            
                            if accessSuccess && refreshSuccess {
                                NotificationCenter.default.post(name: authSuccessNotification, object: nil)
                                completion(true)
                            } else {
                                handleFailure(error: "Failed to save tokens to keychain", completion: completion)
                            }
                        } else {
                            let errorMessage = (json["error"] as? String) ?? "Unexpected response"
                            handleFailure(error: errorMessage, completion: completion)
                        }
                    }
                } catch {
                    handleFailure(error: "Failed to parse response: \(error.localizedDescription)", completion: completion)
                }
            }
        }
        
        task.resume()
    }
    
    private static func handleFailure(error: String, completion: @escaping (Bool) -> Void) {
        Logger.shared.log(error, type: "Error")
        NotificationCenter.default.post(name: authFailureNotification, object: nil, userInfo: ["error": error])
        completion(false)
    }
    
    private static func getRefreshToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: refreshTokenKey,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let tokenData = result as? Data,
              let token = String(data: tokenData, encoding: .utf8) else {
                  return nil
              }
        
        return token
    }
}

