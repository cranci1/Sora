//
// TMDBMatchPopupView.swift
// Sulfur
//
// Created by seiike on 12/06/2025.

import SwiftUI
import NukeUI

struct TMDBMatchPopupView: View {
    let seriesTitle: String
    let onSelect: (Int, TMDBFetcher.MediaType, String) -> Void

    @State private var results: [ResultItem] = []
    @State private var isLoading = true
    @State private var showingError = false

    @Environment(\.dismiss) private var dismiss

    struct ResultItem: Identifiable {
        let id: Int
        let title: String
        let mediaType: TMDBFetcher.MediaType
        let posterURL: String?
    }

    private struct TMDBSearchResult: Decodable {
        let id: Int
        let name: String?
        let title: String?
        let poster_path: String?
        let popularity: Double
    }

    private struct TMDBSearchResponse: Decodable {
        let results: [TMDBSearchResult]
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if results.isEmpty {
                        Text("No matches found")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        LazyVStack(spacing: 15) {
                            ForEach(results) { item in
                                Button {
                                    onSelect(item.id, item.mediaType, item.title)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        if let poster = item.posterURL, let url = URL(string: poster) {
                                            LazyImage(url: url) { state in
                                                if let image = state.imageContainer?.image {
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 50, height: 75)
                                                        .cornerRadius(6)
                                                } else {
                                                    Rectangle()
                                                        .fill(.tertiary)
                                                        .frame(width: 50, height: 75)
                                                        .cornerRadius(6)
                                                }
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                            Text(item.mediaType.rawValue.capitalized)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(11)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 15)
                                            .fill(.ultraThinMaterial)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(
                                                Color.accentColor.opacity(0.2),
                                                lineWidth: 0.5
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("TMDB Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error Fetching Results", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Unable to fetch matches. Please try again later.")
            }
        }
        .onAppear(perform: fetchMatches)
    }

    private func fetchMatches() {
        isLoading = true
        results = []
        let fetcher = TMDBFetcher()
        let apiKey = fetcher.apiKey
        let dispatchGroup = DispatchGroup()
        var temp: [ResultItem] = []
        var encounteredError = false

        for type in TMDBFetcher.MediaType.allCases {
            dispatchGroup.enter()
            let query = seriesTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "https://api.themoviedb.org/3/search/\(type.rawValue)?api_key=\(apiKey)&query=\(query)"
            guard let url = URL(string: urlString) else {
                encounteredError = true
                dispatchGroup.leave()
                continue
            }

            URLSession.shared.dataTask(with: url) { data, _, error in
                defer { dispatchGroup.leave() }
                guard error == nil,
                      let data = data,
                      let response = try? JSONDecoder().decode(TMDBSearchResponse.self, from: data)
                else {
                    encounteredError = true
                    return
                }

                let items = response.results.prefix(6).map { res -> ResultItem in
                    let title = (type == .tv ? res.name : res.title) ?? "Unknown"
                    let poster = res.poster_path.map { "https://image.tmdb.org/t/p/w500\($0)" }
                    return ResultItem(id: res.id, title: title, mediaType: type, posterURL: poster)
                }
                temp.append(contentsOf: items)
            }.resume()
        }

        dispatchGroup.notify(queue: .main) {
            if encounteredError { showingError = true }
            results = Array(temp.prefix(6))
            isLoading = false
        }
    }
}
