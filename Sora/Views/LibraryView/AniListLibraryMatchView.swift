//
//  AniListLibraryMatchView.swift
//  Sora
//
//  Created by Francesco on 15/08/26.
//

import SwiftUI
import NukeUI

struct AniListLibraryMatchView: View {
    let item: LibraryItem
    let collectionId: UUID
    
    @AppStorage("selectedModuleId") private var selectedModuleId: String?
    @EnvironmentObject var moduleManager: ModuleManager
    @EnvironmentObject var libraryManager: LibraryManager
    @StateObject private var jsController = JSController.shared
    
    @State private var results: [SearchItem] = []
    @State private var isLoading = true
    @State private var showingError = false
    
    @Environment(\.dismiss) private var dismiss
    
    private var selectedModule: ScrapingModule? {
        guard let id = selectedModuleId else { return nil }
        return moduleManager.modules.first { $0.id.uuidString == id }
    }
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if selectedModule == nil {
                        Text("Select a source in Search first")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if isLoading {
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
                            ForEach(results) { result in
                                Button {
                                    select(result)
                                } label: {
                                    HStack(spacing: 12) {
                                        if let url = URL(string: result.imageUrl) {
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
                                            Text(result.title)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                            if let module = selectedModule {
                                                Text(module.metadata.sourceName)
                                                    .font(.caption)
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
                                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 0.5)
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
            .navigationTitle("Match Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error Searching Source", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Unable to load the module or fetch results. Please try again.")
            }
        }
        .onAppear(perform: fetchMatches)
    }
    
    private func fetchMatches() {
        guard let module = selectedModule else {
            isLoading = false
            return
        }
        isLoading = true
        results = []
        
        do {
            let jsContent = try moduleManager.getModuleContent(module)
            jsController.loadScript(jsContent)
            
            let handleResults: ([SearchItem]) -> Void = { items in
                DispatchQueue.main.async {
                    let unique = items.reduce(into: [String: SearchItem]()) { dict, item in
                        dict[item.href] = item
                    }.values
                    results = Array(unique)
                    isLoading = false
                }
            }
            
            if module.metadata.asyncJS == true {
                jsController.fetchJsSearchResults(keyword: item.title, module: module, completion: handleResults)
            } else {
                jsController.fetchSearchResults(keyword: item.title, module: module, completion: handleResults)
            }
        } catch {
            Logger.shared.log("Failed to load module for AniList match: \(error)", type: "Error")
            isLoading = false
            showingError = true
        }
    }
    
    private func select(_ result: SearchItem) {
        guard let module = selectedModule else { return }
        libraryManager.resolveAniListPlaceholder(
            itemId: item.id,
            collectionId: collectionId,
            matchedHref: result.href,
            moduleId: module.id.uuidString,
            moduleName: module.metadata.sourceName,
            matchedTitle: result.title,
            matchedImageUrl: result.imageUrl
        )
        dismiss()
    }
}

// MARK: - Placeholder

struct AniListPlaceholderGridItemView: View {
    let item: LibraryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                if let url = URL(string: item.imageUrl) {
                    LazyImage(url: url) { state in
                        if let image = state.imageContainer?.image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(2/3, contentMode: .fill)
                        } else {
                            Rectangle().fill(.tertiary)
                        }
                    }
                } else {
                    Rectangle().fill(.tertiary)
                }
                
                Text("Unmatched")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(6)
            }
            .aspectRatio(2/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
            
            Text(item.title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }
}
