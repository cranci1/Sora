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
    @State private var searchQuery: String
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFieldFocused: Bool
    
    init(item: LibraryItem, collectionId: UUID) {
        self.item = item
        self.collectionId = collectionId
        self._searchQuery = State(initialValue: item.title)
    }
    
    private var selectedModule: ScrapingModule? {
        guard let id = selectedModuleId else { return nil }
        return moduleManager.modules.first { $0.id.uuidString == id }
    }
    
    private func cleanLanguageName(_ language: String?) -> String {
        guard let language = language else { return "Unknown" }
        let cleaned = language.replacingOccurrences(
            of: "\\s*\\([^\\)]*\\)",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
        
        return cleaned.isEmpty ? "Unknown" : cleaned
    }
    
    private func getModulesByLanguage() -> [String: [ScrapingModule]] {
        var result = [String: [ScrapingModule]]()
        for module in moduleManager.modules {
            let language = cleanLanguageName(module.metadata.language)
            result[language, default: []].append(module)
        }
        return result
    }
    
    private func getModuleLanguageGroups() -> [String] {
        getModulesByLanguage().keys.sorted()
    }
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    searchBar
                    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    ModuleSelectorMenu(
                        selectedModule: selectedModule,
                        moduleGroups: getModuleLanguageGroups(),
                        modulesByLanguage: getModulesByLanguage(),
                        selectedModuleId: selectedModuleId,
                        onModuleSelected: { moduleId in
                            selectedModuleId = moduleId
                        }
                    )
                }
            }
            .alert("Error Searching Source", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Unable to load the module or fetch results. Please try again.")
            }
        }
        .onAppear(perform: fetchMatches)
        .onChange(of: selectedModuleId) { _ in
            fetchMatches()
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundColor(.secondary)
            
            TextField("Search title...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.primary)
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .onSubmit(fetchMatches)
            
            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.accentColor.opacity(0.25), location: 0),
                            .init(color: Color.accentColor.opacity(0), location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private func fetchMatches() {
        isSearchFieldFocused = false
        
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let module = selectedModule, !query.isEmpty else {
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
                jsController.fetchJsSearchResults(keyword: query, module: module, completion: handleResults)
            } else {
                jsController.fetchSearchResults(keyword: query, module: module, completion: handleResults)
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
        ZStack {
            LazyImage(url: URL(string: item.imageUrl)) { state in
                if let uiImage = state.imageContainer?.image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(0.72, contentMode: .fill)
                        .frame(width: 162, height: 243)
                        .cornerRadius(12)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(2/3, contentMode: .fit)
                        .redacted(reason: .placeholder)
                }
            }
            .overlay(
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                    Text("Unmatched")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 0.5)
                    )
                    .padding(8),
                alignment: .topLeading
            )
            
            VStack {
                Spacer()
                Text(item.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        LinearGradient(
                            colors: [
                                .black.opacity(0.7),
                                .black.opacity(0.0)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .shadow(color: .black, radius: 4, x: 0, y: 2)
                    )
            }
        }
        .frame(width: 162, height: 243)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
