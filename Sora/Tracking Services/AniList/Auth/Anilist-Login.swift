//
//  Login.swift
//  Ryu
//
//  Created by Francesco on 08/08/24.
//

import UIKit

class AniListLogin {
    static let clientID = "19551"
    static let redirectURI = "sora://anilist"
    
    static let authorizationEndpoint = "https://anilist.co/api/v2/oauth/authorize"
    
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
                    AniListToken.exchangeAuthorizationCodeForToken(code: code) { success in
                        if success {
                            Logger.shared.log("AniList token exchange successful", type: "Debug")
                        } else {
                            Logger.shared.log("AniList token exchange failed", type: "Error")
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
