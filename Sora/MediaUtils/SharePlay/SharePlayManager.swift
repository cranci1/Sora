//
//  SharePlayManager.swift
//  Sora
//
//  Created by Francesco on 15/06/25.
//

import UIKit
import Foundation
import GroupActivities

class SharePlayManager {
    static let shared = SharePlayManager()
    
    private init() {}
    
    func isSharePlayAvailable() -> Bool {
        return true
    }
    
    func presentSharePlayInvitation(from viewController: UIViewController, 
                                    mediaTitle: String, 
                                    episodeNumber: Int, 
                                    streamUrl: String, 
                                    subtitles: String = "", 
                                    aniListID: Int = 0, 
                                    fullUrl: String, 
                                    headers: [String: String]? = nil, 
                                    episodeImageUrl: String = "", 
                                    totalEpisodes: Int = 0, 
                                    tmdbID: Int? = nil, 
                                    isMovie: Bool = false, 
                                    seasonNumber: Int = 1) {
        
        Task { @MainActor in
            var episodeImageData: Data?
            if !episodeImageUrl.isEmpty, let imageUrl = URL(string: episodeImageUrl) {
                do {
                    episodeImageData = try await URLSession.shared.data(from: imageUrl).0
                } catch {
                    Logger.shared.log("Failed to load episode image for SharePlay: \(error.localizedDescription)", type: "Error")
                }
            }
            
            let activity = VideoWatchingActivity(
                mediaTitle: mediaTitle,
                episodeNumber: episodeNumber,
                streamUrl: streamUrl,
                subtitles: subtitles,
                aniListID: aniListID,
                fullUrl: fullUrl,
                headers: headers,
                episodeImageUrl: episodeImageUrl,
                episodeImageData: episodeImageData,
                totalEpisodes: totalEpisodes,
                tmdbID: tmdbID,
                isMovie: isMovie,
                seasonNumber: seasonNumber
            )
            
            do {
                _ = try await activity.activate()
                Logger.shared.log("SharePlay invitation sent successfully", type: "SharePlay")
            } catch {
                Logger.shared.log("Failed to send SharePlay invitation: \(error.localizedDescription)", type: "Error")
                
                let alert = UIAlertController(
                    title: "SharePlay Unavailable", 
                    message: "SharePlay is not available right now. Make sure you're connected to FaceTime or have SharePlay enabled in Control Center.", 
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                viewController.present(alert, animated: true)
            }
        }
    }
}
