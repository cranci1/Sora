//
//  EpisodeCell.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import Kingfisher

struct EpisodeLink: Identifiable {
    let id = UUID()
    let number: Int
    let href: String
}

struct EpisodeCell: View {
    let episodeIndex: Int
    let episode: String
    let episodeID: Int
    let progress: Double
    let itemID: Int
    let module: ScrapingModule
    
    let onTap: (String) -> Void
    let onMarkAllPrevious: () -> Void
    
    @State private var episodeTitle: String = ""
    @State private var episodeImageUrl: String = ""
    @State private var isLoading: Bool = true
    @State private var currentProgress: Double = 0.0
    @State private var showDownloadConfirmation = false
    @State private var isDownloading: Bool = false
    @State private var isPlaying = false
    
    @ObservedObject private var jsController = JSController.shared
    @EnvironmentObject var moduleManager: ModuleManager
    
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedAppearance") private var selectedAppearance: Appearance = .system
    
    var defaultBannerImage: String {
        let isLightMode = selectedAppearance == .light || (selectedAppearance == .system && colorScheme == .light)
        return isLightMode
            ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner1.png"
            : "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner2.png"
    }
    
    init(episodeIndex: Int, episode: String, episodeID: Int, progress: Double,
         itemID: Int, module: ScrapingModule, onTap: @escaping (String) -> Void, onMarkAllPrevious: @escaping () -> Void) {
        self.episodeIndex = episodeIndex
        self.episode = episode
        self.episodeID = episodeID
        self.progress = progress
        self.itemID = itemID
        self.module = module
        self.onTap = onTap
        self.onMarkAllPrevious = onMarkAllPrevious
    }
    
    var body: some View {
        HStack {
            ZStack {
                KFImage(URL(string: episodeImageUrl.isEmpty ? defaultBannerImage : episodeImageUrl))
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 100, height: 56)
                    .cornerRadius(8)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            
            VStack(alignment: .leading) {
                Text("Episode \(episodeID + 1)")
                    .font(.system(size: 15))
                if !episodeTitle.isEmpty {
                    Text(episodeTitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                showDownloadConfirmation = true
            }) {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
            .padding(.horizontal, 8)
            
            CircularProgressBar(progress: currentProgress)
                .frame(width: 40, height: 40)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: {
                showDownloadConfirmation = true
            }) {
                Label("Download Episode", systemImage: "arrow.down.circle")
            }
            
            if progress <= 0.9 {
                Button(action: markAsWatched) {
                    Label("Mark as Watched", systemImage: "checkmark.circle")
                }
            }
            
            if progress != 0 {
                Button(action: resetProgress) {
                    Label("Reset Progress", systemImage: "arrow.counterclockwise")
                }
            }
            
            if episodeIndex > 0 {
                Button(action: onMarkAllPrevious) {
                    Label("Mark All Previous Watched", systemImage: "checkmark.circle.fill")
                }
            }
        }
        .onAppear {
            updateProgress()
            fetchEpisodeDetails()
        }
        .onChange(of: progress) { _ in
            updateProgress()
        }
        .onTapGesture {
            let imageUrl = episodeImageUrl.isEmpty ? defaultBannerImage : episodeImageUrl
            onTap(imageUrl)
        }
        .alert("Download Episode", isPresented: $showDownloadConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Download") {
                downloadEpisode()
            }
        } message: {
            Text("Do you want to download Episode \(episodeID + 1)\(episodeTitle.isEmpty ? "" : ": \(episodeTitle)")?")
        }
    }
    
    private func downloadEpisode() {
        if isDownloading {
            return
        }
        
        isDownloading = true
        let downloadID = UUID()
        
        DropManager.shared.showDrop(
            title: "Preparing Download",
            subtitle: "Episode \(episodeID + 1)",
            duration: 0.5,
            icon: UIImage(systemName: "arrow.down.circle")
        )
        
        Task {
            do {
                let jsContent = try moduleManager.getModuleContent(module)
                jsController.loadScript(jsContent)
                
                if module.metadata.softsub == true {
                    if module.metadata.asyncJS == true {
                        jsController.fetchStreamUrlJS(episodeUrl: episode, softsub: true, module: module) { result in
                            self.handleDownloadResult(result, downloadID: downloadID)
                        }
                        
                        if module.metadata.streamAsyncJS == true {
                            jsController.fetchStreamUrlJSSecond(episodeUrl: episode, softsub: true, module: module) { result in
                                self.handleDownloadResult(result, downloadID: downloadID)
                            }
                        }
                        
                        jsController.fetchStreamUrl(episodeUrl: episode, softsub: true, module: module) { result in
                            self.handleDownloadResult(result, downloadID: downloadID)
                        }
                    } else if module.metadata.streamAsyncJS == true {
                        jsController.fetchStreamUrlJSSecond(episodeUrl: episode, softsub: true, module: module) { result in
                            self.handleDownloadResult(result, downloadID: downloadID)
                        }
                        
                        jsController.fetchStreamUrl(episodeUrl: episode, softsub: true, module: module) { result in
                            self.handleDownloadResult(result, downloadID: downloadID)
                        }
                    } else {
                        jsController.fetchStreamUrl(episodeUrl: episode, softsub: true, module: module) { result in
                            self.handleDownloadResult(result, downloadID: downloadID)
                        }
                    }
                } else {
                    if module.metadata.asyncJS == true {
                        jsController.fetchStreamUrlJS(episodeUrl: episode, module: module) { result in
                            self.handleDownloadResult(result, downloadID: downloadID)
                        }
                        
                        if module.metadata.streamAsyncJS == true {
                            jsController.fetchStreamUrlJSSecond(episodeUrl: episode, module: module) { result in
                                self.handleDownloadResult(result, downloadID: downloadID)
                            }
                        }
                        
                        jsController.fetchStreamUrl(episodeUrl: episode, module: module) { result in
                            self.handleDownloadResult(result, downloadID: downloadID)
                        }
                    } else if module.metadata.streamAsyncJS == true {
                        jsController.fetchStreamUrlJSSecond(episodeUrl: episode, module: module) { result in
                            self.handleDownloadResult(result, downloadID: downloadID)
                        }
                        
                        jsController.fetchStreamUrl(episodeUrl: episode, module: module) { result in
                            self.handleDownloadResult(result, downloadID: downloadID)
                        }
                    } else {
                        jsController.fetchStreamUrl(episodeUrl: episode, module: module) { result in
                            self.handleDownloadResult(result, downloadID: downloadID)
                        }
                    }
                }
            } catch {
                DropManager.shared.error("Failed to start download: \(error.localizedDescription)")
                isDownloading = false
            }
        }
    }
    
    private func handleDownloadResult(_ result: (streams: [String]?, subtitles: [String]?), downloadID: UUID) {
        // Only process this result if we're still downloading the same episode
        if !isDownloading {
            return
        }
        
        if let streams = result.streams, !streams.isEmpty {
            // Get the first stream URL
            let streamUrl = streams[0]
            
            // Extract base URL for headers
            var headers: [String: String] = [:]
            if let url = URL(string: streamUrl) {
                // Always use the module's baseUrl for Origin and Referer
                if !module.metadata.baseUrl.isEmpty && !module.metadata.baseUrl.contains("undefined") {
                    print("Using module baseUrl: \(module.metadata.baseUrl)")
                    
                    // Create comprehensive headers prioritizing the module's baseUrl
                    headers = [
                        "Origin": module.metadata.baseUrl,
                        "Referer": module.metadata.baseUrl,
                        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
                        "Accept": "*/*",
                        "Accept-Language": "en-US,en;q=0.9",
                        "Sec-Fetch-Dest": "empty",
                        "Sec-Fetch-Mode": "cors",
                        "Sec-Fetch-Site": "same-origin"
                    ]
                } else {
                    // Fallback to using the stream URL's domain if module.baseUrl isn't available
                    if let scheme = url.scheme, let host = url.host {
                        let baseUrl = scheme + "://" + host
                        
                        headers = [
                            "Origin": baseUrl,
                            "Referer": baseUrl,
                            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
                            "Accept": "*/*",
                            "Accept-Language": "en-US,en;q=0.9",
                            "Sec-Fetch-Dest": "empty",
                            "Sec-Fetch-Mode": "cors",
                            "Sec-Fetch-Site": "same-origin"
                        ]
                    } else {
                        // Missing URL components
                        DropManager.shared.error("Invalid stream URL - missing scheme or host")
                        isDownloading = false
                        return
                    }
                }
                
                print("Download headers: \(headers)")
                
                // Use jsController to handle the download with comprehensive headers
                jsController.downloadWithM3U8Support(url: url, headers: headers, title: "Episode \(episodeID + 1)")
                
                DropManager.shared.success("Download started for Episode \(episodeID + 1)")
                
                // Log the download for analytics
                Logger.shared.log("Started download for Episode \(episodeID + 1): \(episode)", type: "Download")
                AnalyticsManager.shared.sendEvent(
                    event: "download",
                    additionalData: ["episode": episodeID + 1, "url": streamUrl]
                )
                
                // Mark that we've handled this download
                isDownloading = false
            } else {
                // Invalid URL
                DropManager.shared.error("Invalid stream URL format")
                isDownloading = false
            }
        } else {
            // If we didn't find any streams, show an error
            DropManager.shared.error("No valid stream found for download")
            isDownloading = false
        }
    }
    
    private func markAsWatched() {
        let userDefaults = UserDefaults.standard
        let totalTime = 1000.0
        let watchedTime = totalTime
        userDefaults.set(watchedTime, forKey: "lastPlayedTime_\(episode)")
        userDefaults.set(totalTime, forKey: "totalTime_\(episode)")
        DispatchQueue.main.async {
            self.updateProgress()
        }
    }
    
    private func resetProgress() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(0.0, forKey: "lastPlayedTime_\(episode)")
        userDefaults.set(0.0, forKey: "totalTime_\(episode)")
        DispatchQueue.main.async {
            self.updateProgress()
        }
    }
    
    private func updateProgress() {
        let userDefaults = UserDefaults.standard
        let lastPlayedTime = userDefaults.double(forKey: "lastPlayedTime_\(episode)")
        let totalTime = userDefaults.double(forKey: "totalTime_\(episode)")
        currentProgress = totalTime > 0 ? min(lastPlayedTime / totalTime, 1.0) : 0
    }
    
    private func fetchEpisodeDetails() {
        fetchAnimeEpisodeDetails()
    }
    
    private func fetchAnimeEpisodeDetails() {
        guard let url = URL(string: "https://api.ani.zip/mappings?anilist_id=\(itemID)") else {
            isLoading = false
            return
        }
        
        URLSession.custom.dataTask(with: url) { data, _, error in
            if let error = error {
                Logger.shared.log("Failed to fetch anime episode details: \(error)", type: "Error")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any],
                      let episodes = json["episodes"] as? [String: Any],
                      let episodeDetails = episodes["\(episodeID + 1)"] as? [String: Any],
                      let title = episodeDetails["title"] as? [String: String],
                      let image = episodeDetails["image"] as? String else {
                          Logger.shared.log("Invalid anime response format", type: "Error")
                          DispatchQueue.main.async { self.isLoading = false }
                          return
                      }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    if UserDefaults.standard.object(forKey: "fetchEpisodeMetadata") == nil
                        || UserDefaults.standard.bool(forKey: "fetchEpisodeMetadata") {
                        self.episodeTitle   = title["en"] ?? ""
                        self.episodeImageUrl = image
                    }
                }
            } catch {
                DispatchQueue.main.async { self.isLoading = false }
            }
        }.resume()
    }
}
