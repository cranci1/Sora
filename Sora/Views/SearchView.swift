//
//  SearchView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher

struct SearchItem: Identifiable {
    let id = UUID()
    let title: String
    let imageUrl: String
    let href: String
}

struct SearchView: View {
    @AppStorage("selectedModuleId") private var selectedModuleId: String?
    @StateObject private var jsController = JSController()
    @EnvironmentObject var moduleManager: ModuleManager
    
    @State private var searchItems: [SearchItem] = []
    @State private var selectedSearchItem: SearchItem?
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var hasNoResults = false
    
    private var selectedModule: ScrapingModule? {
        guard let id = selectedModuleId else { return nil }
        return moduleManager.modules.first { $0.id.uuidString == id }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    SearchBar(text: $searchText, onSearchButtonClicked: performSearch)
                        .padding()
                        .disabled(selectedModule == nil)
                    
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
                    
                    if isSearching {
                        ProgressView()
                            .padding()
                    } else if hasNoResults {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No Results Found")
                                .font(.headline)
                            Text("Try different keywords/titles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                        ForEach(searchItems) { item in
                            NavigationLink(destination: MediaInfoView(title: item.title, imageUrl: item.imageUrl, href: item.href, module: selectedModule!)) {
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
            searchItems = []
            hasNoResults = false
            return
        }
        
        isSearching = true
        hasNoResults = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task {
                do {
                    let jsContent = try moduleManager.getModuleContent(module)
                    jsController.loadScript(jsContent)
                    if module.metadata.asyncJS == true {
                        jsController.fetchJsSearchResults(keyword: searchText, module: module) { items in
                            searchItems = items
                            hasNoResults = items.isEmpty
                            isSearching = false
                        }
                    } else {
                        jsController.fetchSearchResults(keyword: searchText, module: module) { items in
                            searchItems = items
                            hasNoResults = items.isEmpty
                            isSearching = false
                        }
                    }
                } catch {
                    print("Error loading module: \(error)")
                    Logger.shared.log("Error loading module: \(error).", level: .info)
                    isSearching = false
                    hasNoResults = true
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
