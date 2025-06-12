//
//  Trakt-Login.swift
//  Sulfur
//
//  Created by Francesco on 13/04/25.
//

import UIKit

class TraktLogin {
    static let clientID = "6ec81bf19deb80fdfa25652eef101576ca6aaa0dc016d36079b2de413d71c369"
    static let redirectURI = "sora://trakt"
    
    static let authorizationEndpoint = "https://trakt.tv/oauth/authorize"
    
    static func authenticate() {
        let urlString = "\(authorizationEndpoint)?client_id=\(clientID)&redirect_uri=\(redirectURI)&response_type=code"
        guard let url = URL(string: urlString) else {
            Logger.shared.log("Invalid authorization URL", type: "Error")
            return
        }
        
        WebAuthenticationManager.shared.authenticate(url: url, callbackScheme: "sora") { result in
            switch result {
            case .success(let callbackURL):
                if let params = callbackURL.queryParameters,
                   let code = params["code"] {
                    TraktToken.exchangeAuthorizationCodeForToken(code: code) { success in
                        if success {
                            Logger.shared.log("Trakt token exchange successful", type: "Debug")
                        } else {
                            Logger.shared.log("Trakt token exchange failed", type: "Error")
                        }
                    }
                } else {
                    Logger.shared.log("No authorization code in callback URL", type: "Error")
                }
            case .failure(let error):
                Logger.shared.log("Authentication failed: \(error.localizedDescription)", type: "Error")
            }
        }
    }
}
