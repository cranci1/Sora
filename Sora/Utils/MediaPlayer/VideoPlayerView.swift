//
//  VideoPlayerView.swift
//  Sora
//
//  Created by Francesco on 3/06/25.
//

import SwiftUI
import AVKit

struct VideoPlayerView: UIViewControllerRepresentable {
    let module: ScrapingModule
    var streamUrl: String?
    var fullUrl: String
    var subtitles: String
    var aniListID: Int
    var headers: [String:String]?
    var totalEpisodes: Int
    var episodeNumber: Int
    var episodeImageUrl: String
    var mediaTitle: String

    func makeUIViewController(context: Context) -> VideoPlayerViewController {
        let controller = VideoPlayerViewController(module: module)
        controller.streamUrl = streamUrl
        controller.fullUrl = fullUrl
        controller.subtitles = subtitles
        controller.aniListID = aniListID
        controller.headers = headers
        controller.totalEpisodes = totalEpisodes
        controller.episodeNumber = episodeNumber
        controller.episodeImageUrl = episodeImageUrl
        controller.mediaTitle = mediaTitle
        return controller
    }

    func updateUIViewController(_ uiViewController: VideoPlayerViewController, context: Context) {
    }
}
