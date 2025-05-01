//
//  DownloadView.swift
//  Sulfur
//
//  Created by Francesco on 29/04/25.
//

import SwiftUI
import AVKit

struct DownloadView: View {
    @StateObject private var viewModel = DownloadManager()
    @State private var hlsURL = "https://test-streams.mux.dev/x36xhzz/url_6/193039199_mp4_h264_aac_hq_7.m3u8"
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Enter HLS URL", text: $hlsURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button("Download Stream") {
                    viewModel.downloadAsset(from: URL(string: hlsURL)!)
                }
                .padding()
                
                List(viewModel.activeDownloads, id: \.0) { (url, progress) in
                    VStack(alignment: .leading) {
                        Text(url.absoluteString)
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                }
                
                NavigationLink("Play Offline Content") {
                    if let url = viewModel.localPlaybackURL {
                        VideoPlayer(player: AVPlayer(url: url))
                    } else {
                        Text("No offline content available")
                    }
                }
                .padding()
            }
            .navigationTitle("HLS Downloader")
        }
    }
}
