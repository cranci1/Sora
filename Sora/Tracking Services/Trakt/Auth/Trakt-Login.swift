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
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    Logger.shared.log("Safari opened successfully", type: "Debug")
                } else {
                    Logger.shared.log("Failed to open Safari", type: "Error")
                }
            }
        } else {
            Logger.shared.log("Cannot open URL", type: "Error")
        }
    }
}
