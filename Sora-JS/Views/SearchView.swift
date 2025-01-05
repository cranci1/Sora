//
//  SearchView.swift
//  Sora-JS
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher

struct MediaItem: Identifiable {
    let id = UUID()
    let title: String
    let imageUrl: String
}

struct SearchView: View {
    @StateObject private var jsController = JSController()
    @EnvironmentObject var moduleManager: ModuleManager
    @State private var searchText = ""
    @State private var mediaItems: [MediaItem] = []
    @State private var isSearching = false
    @AppStorage("selectedModuleId") private var selectedModuleId: String?
    
    private var selectedModule: ScrapingModule? {
        guard let id = selectedModuleId else { return nil }
        return moduleManager.modules.first { $0.id.uuidString == id }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    if selectedModule == nil {
                        VStack(spacing: 8) {
                            Text("No Module Selected")
                                .font(.headline)
                            Text("Please select a module from settings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                    }
                    
                    SearchBar(text: $searchText, onSearchButtonClicked: performSearch)
                        .padding()
                        .disabled(selectedModule == nil)
                    
                    if isSearching {
                        ProgressView()
                            .padding()
                    }
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                        ForEach(mediaItems) { item in
                            VStack {
                                KFImage(URL(string: item.imageUrl))
                                    .resizable()
                                    .aspectRatio(2/3, contentMode: .fill)
                                    .cornerRadius(10)
                                    .frame(width: 150, height: 225)
                                
                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundColor(Color.primary)
                                    .padding([.leading, .bottom], 8)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if let selectedModule = selectedModule {
                            Text(selectedModule.metadata.sourceName)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        Menu {
                            ForEach(moduleManager.modules) { module in
                                Button {
                                    selectedModuleId = module.id.uuidString
                                } label: {
                                    HStack {
                                        KFImage(URL(string: module.metadata.iconUrl))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 20, height: 20)
                                            .cornerRadius(4)
                                        
                                        Text(module.metadata.sourceName)
                                        Spacer()
                                        if module.id.uuidString == selectedModuleId {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: selectedModuleId) { _ in
            if !searchText.isEmpty {
                performSearch()
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty, let module = selectedModule else {
            mediaItems = []
            return
        }
        
        isSearching = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task {
                do {
                    let jsContent = try moduleManager.getModuleContent(module)
                    jsController.loadScript(jsContent)
                    jsController.searchContent(keyword: searchText, module: module) { items in
                        mediaItems = items
                        isSearching = false
                    }
                } catch {
                    print("Error loading module: \(error)")
                    isSearching = false
                }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            TextField("Search...", text: $text, onCommit: onSearchButtonClicked)
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                        
                        if !text.isEmpty {
                            Button(action: {
                                self.text = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.secondary)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
        }
    }
}