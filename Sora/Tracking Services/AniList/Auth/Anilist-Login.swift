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
            return
        }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    Logger.shared.log("Safari opened successfully", type: .debug)
                } else {
                    Logger.shared.log("Failed to open Safari", type: .error)
                }
            }
        } else {
            Logger.shared.log("Cannot open URL", type: .error)
        }
    }
}
