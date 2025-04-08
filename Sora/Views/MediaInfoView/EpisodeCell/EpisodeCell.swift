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
    
    let onTap: (String) -> Void
    let onMarkAllPrevious: () -> Void
    
    @State private var episodeTitle: String = ""
    @State private var episodeImageUrl: String = ""
    @State private var isLoading: Bool = true
    @State private var currentProgress: Double = 0.0
    
    var body: some View {
        HStack {
            ZStack {
                KFImage(URL(string: episodeImageUrl.isEmpty ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/banner2.png" : episodeImageUrl))
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
            
            CircularProgressBar(progress: currentProgress)
                .frame(width: 40, height: 40)
        }
        .contentShape(Rectangle())
        .contextMenu {
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
            
            if UserDefaults.standard.object(forKey: "fetchEpisodeMetadata") == nil
                || UserDefaults.standard.bool(forKey: "fetchEpisodeMetadata") {
                fetchEpisodeDetails()
            }
        }
        .onChange(of: progress) { newProgress in
            updateProgress()
        }
        .onTapGesture {
            let imageUrl = episodeImageUrl.isEmpty ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/banner2.png" : episodeImageUrl
            onTap(imageUrl)
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
        guard let url = URL(string: "https://api.ani.zip/mappings?anilist_id=\(itemID)") else {
            isLoading = false
            return
        }
        
        Logger.shared.log("AniList mapping request triggered for itemID: \(itemID), episode: \(episodeID + 1)", type: "AniList")
        AnalyticsManager.shared.sendEvent(event: "AniListMappingRequest", additionalData: ["itemID": "\(itemID)", "episode": "\(episodeID + 1)"])
        
        URLSession.custom.dataTask(with: url) { data, _, error in
            if let error = error {
                Logger.shared.log("AniList mapping request for itemID: \(itemID), episode: \(episodeID + 1) failed with error: \(error.localizedDescription)", type: "Error")
                AnalyticsManager.shared.sendEvent(event: "AniListMappingRequestFailed", additionalData: ["itemID": "\(itemID)", "episode": "\(episodeID + 1)", "error": error.localizedDescription])
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            guard let data = data else {
                Logger.shared.log("AniList mapping request for itemID: \(itemID), episode: \(episodeID + 1) failed: No data received", type: "Error")
                AnalyticsManager.shared.sendEvent(event: "AniListMappingRequestNoData", additionalData: ["itemID": "\(itemID)", "episode": "\(episodeID + 1)"])
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any],
                      let episodes = json["episodes"] as? [String: Any],
                      let episodeDetails = episodes["\(episodeID + 1)"] as? [String: Any],
                      let titleDict = episodeDetails["title"] as? [String: String],
                      let image = episodeDetails["image"] as? String else {
                    let responseStr = String(data: data, encoding: .utf8) ?? "Unable to convert response data to string"
                    Logger.shared.log("AniList mapping request for itemID: \(itemID), episode: \(episodeID + 1) returned invalid response. Full response: \(responseStr)", type: "Error")
                    AnalyticsManager.shared.sendEvent(event: "AniListMappingInvalidResponse", additionalData: ["itemID": "\(itemID)", "episode": "\(episodeID + 1)", "response": responseStr])
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.episodeTitle = titleDict["en"] ?? ""
                    self.episodeImageUrl = image
                    self.isLoading = false
                    Logger.shared.log("AniList mapping response for itemID: \(itemID), episode: \(episodeID + 1) succeeded", type: "AniList")
                    AnalyticsManager.shared.sendEvent(event: "AniListMappingResponse", additionalData: ["itemID": "\(itemID)", "episode": "\(episodeID + 1)", "title": self.episodeTitle])
                }
            } catch {
                let responseStr = String(data: data, encoding: .utf8) ?? "Unable to convert response data to string"
                Logger.shared.log("AniList mapping request for itemID: \(itemID), episode: \(episodeID + 1) failed with error: \(error.localizedDescription). Full response: \(responseStr)", type: "Error")
                AnalyticsManager.shared.sendEvent(event: "AniListMappingRequestFailed", additionalData: ["itemID": "\(itemID)", "episode": "\(episodeID + 1)", "error": error.localizedDescription, "response": responseStr])
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }
}
