//
// AnilistMatchPopupView.swift
// Sulfur
//
// Created by seiike on 01/06/2025.

import NukeUI
import SwiftUI

struct AnilistMatchPopupView: View {
    let seriesTitle: String
    let onSelect: (Int, String, Int?) -> Void // id, title, malId

    @State private var results: [[String: Any]] = []
    @State private var isLoading = true

    @AppStorage("selectedAppearance") private var selectedAppearance: Appearance = .system
    @Environment(\.colorScheme) private var colorScheme

    private var isLightMode: Bool {
        selectedAppearance == .light
            || (selectedAppearance == .system && colorScheme == .light)
    }

    @State private var manualIDText: String = ""
    @State private var showingManualIDAlert = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("".uppercased())
                        .font(.footnote)
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 10)

                    VStack(spacing: 0) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if results.isEmpty {
                            Text("No AniList matches found")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            LazyVStack(spacing: 15) {
                                ForEach(results.indices, id: \.self) { index in
                                    let result = results[index]
                                    Button(action: {
                                        if let id = result["id"] as? Int {
                                            let title = result["title"] as? String ?? seriesTitle
                                            let malId = result["mal_id"] as? Int
                                            Logger.shared.log("Selected AniList ID: \(id), MAL ID: \(malId?.description ?? "nil")", type: "AnilistMatch")
                                            onSelect(id, title, malId)
                                            dismiss()
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            if let cover = result["cover"] as? String,
                                               let url = URL(string: cover) {
                                                LazyImage(url: url) { state in
                                                    if let uiImage = state.imageContainer?.image {
                                                        Image(uiImage: uiImage)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: 50, height: 70)
                                                            .cornerRadius(6)
                                                    } else {
                                                        Rectangle()
                                                            .fill(.tertiary)
                                                            .frame(width: 50, height: 70)
                                                            .cornerRadius(6)
                                                    }
                                                }
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(result["title"] as? String ?? "Unknown")
                                                    .font(.body)
                                                    .foregroundStyle(.primary)
                                                if let english = result["title_english"] as? String {
                                                    Text(english)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                if let malId = result["mal_id"] as? Int {
                                                    Text("MAL ID: \(malId)")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
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
                                                    LinearGradient(
                                                        stops: [
                                                            .init(color: Color.accentColor.opacity(0.25), location: 0),
                                                            .init(color: Color.accentColor.opacity(0),  location: 1)
                                                        ],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    ),
                                                    lineWidth: 0.5
                                                )
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 15))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        }
                    }

                    if !results.isEmpty {
                        Text("Tap a title to override the current match.")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 2)
            }
            .navigationTitle("AniList Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(isLightMode ? .black : .white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        manualIDText = ""
                        showingManualIDAlert = true
                    } label: {
                        Image(systemName: "number")
                            .foregroundColor(isLightMode ? .black : .white)
                    }
                }
            }
            .alert("Set Custom AniList ID", isPresented: $showingManualIDAlert) {
                TextField("AniList ID", text: $manualIDText)
                    .keyboardType(.numberPad)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    if let idInt = Int(manualIDText.trimmingCharacters(in: .whitespaces)) {
                        Logger.shared.log("Manual AniList ID: \(idInt), MAL ID: nil", type: "AnilistMatch")
                        onSelect(idInt, seriesTitle, nil)
                        dismiss()
                    }
                }
            } message: {
                Text("Enter the AniList ID for this series")
            }
        }
        .onAppear(perform: fetchMatches)
    }

    private func fetchMatches() {
        let query = """
        query {
          Page(page: 1, perPage: 6) {
            media(search: "\(seriesTitle)", type: ANIME) {
              id
              idMal
              title {
                romaji
                english
              }
              coverImage {
                large
              }
            }
          }
        }
        """

        guard let url = URL(string: "https://graphql.anilist.co") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["query": query])

        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                isLoading = false
                guard
                    let data = data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let dataDict = json["data"] as? [String: Any],
                    let page = dataDict["Page"] as? [String: Any],
                    let mediaList = page["media"] as? [[String: Any]]
                else { return }

                results = mediaList.map { media in
                    let titleInfo = media["title"] as? [String: Any]
                    let cover = (media["coverImage"] as? [String: Any])?["large"] as? String
                    return [
                        "id": media["id"] ?? 0,
                        "mal_id": media["idMal"] as? Int ?? 0,
                        "title": titleInfo?["romaji"] ?? "Unknown",
                        "title_english": titleInfo?["english"] as Any,
                        "cover": cover as Any
                    ]
                }
            }
        }.resume()
    }
}