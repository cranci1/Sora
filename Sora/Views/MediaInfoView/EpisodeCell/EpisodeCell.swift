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
    let isAnime: Bool
    let tmdbID: Int?
    
    let onTap: (String) -> Void
    let onMarkAllPrevious: () -> Void
    
    @State private var episodeTitle: String = ""
    @State private var episodeImageUrl: String = ""
    @State private var isLoading: Bool = true
    @State private var currentProgress: Double = 0.0
    
    init(episodeIndex: Int, episode: String, episodeID: Int, progress: Double, 
         itemID: Int, isAnime: Bool = true, tmdbID: Int? = nil, 
         onTap: @escaping (String) -> Void, onMarkAllPrevious: @escaping () -> Void) {
        self.episodeIndex = episodeIndex
        self.episode = episode
        self.episodeID = episodeID
        self.progress = progress
        self.itemID = itemID
        self.isAnime = isAnime
        self.tmdbID = tmdbID
        self.onTap = onTap
        self.onMarkAllPrevious = onMarkAllPrevious
    }
    
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
        if isAnime {
            fetchAnimeEpisodeDetails()
        } else {
            fetchTMDBEpisodeDetails()
        }
    }
    
    private func fetchAnimeEpisodeDetails() {
        guard let url = URL(string: "https://api.ani.zip/mappings?anilist_id=\(itemID)") else {
            isLoading = false
            return
        }
        
        URLSession.custom.dataTask(with: url) { data, _, error in
            if let error = error {
                Logger.shared.log("Failed to fetch anime episode details: \(error)", type: "Error")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            guard let data = data else {
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
                      let title = episodeDetails["title"] as? [String: String],
                      let image = episodeDetails["image"] as? String else {
                          Logger.shared.log("Invalid anime response format", type: "Error")
                          DispatchQueue.main.async {
                              self.isLoading = false
                          }
                          return
                      }
                
                DispatchQueue.main.async {
                    self.episodeTitle = title["en"] ?? ""
                    self.episodeImageUrl = image
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }
    
    private func fetchTMDBEpisodeDetails() {
        guard let tmdbID = tmdbID else {
            isLoading = false
            return
        }
        
        let seasonNumber = 1 
        let apiKey = "738b4edd0a156cc126dc4a4b8aea4aca"
        let urlString = "https://api.themoviedb.org/3/tv/\(tmdbID)/season/\(seasonNumber)/episode/\(episodeID + 1)?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }
        
        URLSession.custom.dataTask(with: url) { data, response, error in
            if let error = error {
                Logger.shared.log("Failed to fetch TMDB episode details: \(error)", type: "Error")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let episodeDetails = jsonObject as? [String: Any],
                      let name = episodeDetails["name"] as? String else {
                    Logger.shared.log("Invalid TMDB response format", type: "Error")
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                let imageBasePath = "https://image.tmdb.org/t/p/w300"
                var imageUrl = ""
                if let stillPath = episodeDetails["still_path"] as? String {
                    imageUrl = imageBasePath + stillPath
                }
                
                DispatchQueue.main.async {
                    self.episodeTitle = name
                    self.episodeImageUrl = imageUrl
                    self.isLoading = false
                }
            } catch {
                Logger.shared.log("Error parsing TMDB data: \(error)", type: "Error")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }
}
