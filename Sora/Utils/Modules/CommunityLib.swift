//
//  CommunityLib.swift
//  Sulfur
//
//  Created by seiike on 23/04/2025.
//
import SwiftUI
import Kingfisher

// 1) Model matching your server’s JSON for community-hosted modules.
//    Make sure your endpoint returns something like:
//    [ { "id": "abc", "metadataUrl": "...json", "metadata": { … } }, … ]
struct CommunityModule: Identifiable, Decodable {
    let id: String
    let metadataUrl: String
    let metadata: ModuleMetadata
}

struct CommunityLibraryView: View {
    @EnvironmentObject var moduleManager: ModuleManager

    @State private var modules: [CommunityModule] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedModule: CommunityModule?

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                List(modules) { mod in
                    Button {
                        // instantly show your add-module UI
                        selectedModule = mod
                    } label: {
                        HStack {
                            KFImage(URL(string: mod.metadata.iconUrl))
                                .resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            VStack(alignment: .leading) {
                                Text(mod.metadata.sourceName)
                                    .font(.headline)
                                Text("v\(mod.metadata.version)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Community Modules")
        .onAppear(perform: loadCommunity)
        // drive your existing ModuleAdditionSettingsView as a sheet
        .sheet(item: $selectedModule) { mod in
            ModuleAdditionSettingsView(moduleUrl: mod.metadataUrl)
                .environmentObject(moduleManager)
        }
    }

    private func loadCommunity() {
        guard let url = URL(string: "https://sora.jm26.net/library/modules.json") else {
            errorMessage = "Bad URL"
            isLoading = false
            return
        }
        URLSession.fetchData(allowRedirects: true)
            .dataTask(with: url) { data, _, err in
                DispatchQueue.main.async {
                    if let err = err {
                        errorMessage = err.localizedDescription
                    } else if let d = data {
                        do {
                            modules = try JSONDecoder().decode([CommunityModule].self, from: d)
                        } catch {
                            errorMessage = "Decode error: \(error)"
                        }
                    } else {
                        errorMessage = "No data"
                    }
                    isLoading = false
                }
            }
            .resume()
    }
}
