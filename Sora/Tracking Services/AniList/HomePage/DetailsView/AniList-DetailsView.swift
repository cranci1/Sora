//
//  AniList-DetailsView.swift
//  Sora
//
//  Created by Francesco on 11/02/25.
//

import SwiftUI
import Kingfisher

struct MediaDetailItem: View {
    var title: String
    var value: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

struct AniListDetailsView: View {
    let animeID: Int
    @State private var mediaInfo: [String: Any]?
    @State private var isLoading: Bool = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView()
                        .padding()
                } else if let media = mediaInfo {
                    HStack(alignment: .bottom) {
                        if let coverDict = media["coverImage"] as? [String: Any],
                           let posterURLString = coverDict["extraLarge"] as? String,
                           let posterURL = URL(string: posterURLString) {
                            KFImage(posterURL)
                                .placeholder {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 150, height: 225)
                                        .shimmering()
                                }
                                .resizable()
                                .aspectRatio(2/3, contentMode: .fill)
                                .cornerRadius(10)
                                .frame(width: 150, height: 225)
                        }
                        
                        if let titleDict = media["title"] as? [String: Any],
                           let userPreferred = titleDict["userPreferred"] as? String {
                            Text(userPreferred)
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    
                    Divider()
                        .frame(height: 2)
                        .background(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            if let type = media["type"] as? String {
                                MediaDetailItem(title: "Type", value: type)
                            }
                            if let episodes = media["episodes"] as? Int {
                                MediaDetailItem(title: "Episodes", value: "\(episodes)")
                            }
                            if let duration = media["duration"] as? Int {
                                MediaDetailItem(title: "Length", value: "\(duration) mins")
                            }
                            if let format = media["format"] as? String {
                                MediaDetailItem(title: "Format", value: format)
                            }
                            if let status = media["status"] as? String {
                                MediaDetailItem(title: "Status", value: status)
                            }
                            if let season = media["season"] as? String {
                                MediaDetailItem(title: "Season", value: season)
                            }
                            if let startDate = media["startDate"] as? [String: Any],
                               let year = startDate["year"] as? Int,
                               let month = startDate["month"] as? Int,
                               let day = startDate["day"] as? Int {
                                MediaDetailItem(title: "Start Date", value: "\(year)-\(month)-\(day)")
                            }
                            if let endDate = media["endDate"] as? [String: Any],
                               let year = endDate["year"] as? Int,
                               let month = endDate["month"] as? Int,
                               let day = endDate["day"] as? Int {
                                MediaDetailItem(title: "End Date", value: "\(year)-\(month)-\(day)")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }
                    
                    Divider()
                        .frame(height: 2)
                        .background(.secondary)
                    
                    if let trailer = media["trailer"] as? [String: Any],
                       let trailerID = trailer["id"] as? String,
                       let site = trailer["site"] as? String {
                        if site.lowercased() == "youtube",
                           let url = URL(string: "https://www.youtube.com/watch?v=\(trailerID)") {
                            Link("Watch Trailer on YouTube", destination: url)
                                .padding(.top, 4)
                        } else {
                            Text("Trailer available on \(site)")
                                .padding(.top, 4)
                        }
                    }
                    
                    if let synopsis = media["description"] as? String {
                        Text(synopsis)
                            .padding(.horizontal)
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    
                    Divider()
                        .frame(height: 2)
                        .background(.secondary)
                    
                    if let charactersDict = media["characters"] as? [String: Any],
                       let edges = charactersDict["edges"] as? [[String: Any]] {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Characters")
                                .font(.headline)
                                .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(edges.enumerated()), id: \.offset) { _, edge in
                                        if let node = edge["node"] as? [String: Any],
                                           let nameDict = node["name"] as? [String: Any],
                                           let fullName = nameDict["full"] as? String,
                                           let imageDict = node["image"] as? [String: Any],
                                           let imageUrlStr = imageDict["large"] as? String,
                                           let imageUrl = URL(string: imageUrlStr) {
                                            VStack {
                                                KFImage(imageUrl)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 110, height: 110)
                                                    .clipShape(Circle())
                                                Text(fullName)
                                                    .font(.caption)
                                            }
                                            .frame(width: 115, height: 125)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Divider()
                        .frame(height: 2)
                        .background(.secondary)
                    
                    if let stats = media["stats"] as? [String: Any],
                       let scoreDistribution = stats["scoreDistribution"] as? [[String: Any]] {
                        VStack(alignment: .center) {
                            Text("Score Distribution")
                                .font(.headline)
                            HStack(alignment: .bottom, spacing: 8) {
                                let maxValue = scoreDistribution.compactMap { $0["amount"] as? Int }.max() ?? 1
                                ForEach(Array(scoreDistribution.enumerated()), id: \.offset) { _, dataPoint in
                                    if let score = dataPoint["score"] as? Int,
                                       let amount = dataPoint["amount"] as? Int {
                                        VStack {
                                            Rectangle()
                                                .fill(Color.accentColor)
                                                .frame(width: 20, height: CGFloat(amount) / CGFloat(maxValue) * 100)
                                            Text("\(score)")
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .frame(height: 2)
                        .background(.secondary)
                    
                    if let relations = media["relations"] as? [String: Any],
                       let nodes = relations["nodes"] as? [[String: Any]] {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Correlation")
                                .font(.headline)
                                .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                                        if let titleDict = node["title"] as? [String: Any],
                                           let title = titleDict["userPreferred"] as? String,
                                           let coverImageDict = node["coverImage"] as? [String: Any],
                                           let imageUrlStr = coverImageDict["extraLarge"] as? String,
                                           let imageUrl = URL(string: imageUrlStr) {
                                            VStack {
                                                KFImage(imageUrl)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 100, height: 150)
                                                    .cornerRadius(10)
                                                Text(title)
                                                    .font(.caption)
                                            }
                                            .frame(width: 130, height: 195)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                } else {
                    Text("Failed to load media details.")
                        .padding()
                }
            }
        }
        .navigationBarTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            fetchDetails()
        }
    }
    
    private func fetchDetails() {
        AnilistServiceMediaInfo.fetchAnimeDetails(animeID: animeID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let media):
                    self.mediaInfo = media
                case .failure(let error):
                    print("Error: \(error)")
                }
                self.isLoading = false
            }
        }
    }
}
