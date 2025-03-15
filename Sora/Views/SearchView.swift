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
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 2
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 4

    @StateObject private var jsController = JSController()
    @EnvironmentObject var moduleManager: ModuleManager
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @State private var searchItems: [SearchItem] = []
    @State private var selectedSearchItem: SearchItem?
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var hasNoResults = false
    @State private var isLandscape: Bool = UIDevice.current.orientation.isLandscape
    
    private var selectedModule: ScrapingModule? {
        guard let id = selectedModuleId else { return nil }
        return moduleManager.modules.first { $0.id.uuidString == id }
    }
    
    private var loadingMessages: [String] = [
        "Searching the depths...",
        "Looking for results...",
        "Fetching data...",
        "Please wait...",
        "Almost there..."
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                let columnsCount = determineColumns()
                
                VStack(spacing: 0) {
                    HStack {
                        SearchBar(text: $searchText, onSearchButtonClicked: performSearch)
                            .padding(.leading)
                            .padding(.trailing, searchText.isEmpty ? 16 : 0)
                            .disabled(selectedModule == nil)
                            .padding(.top)
                        
                        if !searchText.isEmpty {
                            Button("Cancel") {
                                searchText = ""
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                            .padding(.trailing)
                            .padding(.top)
                        }
                    }
                    
                    if selectedModule == nil {
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.app")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
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
                    
                    if !searchText.isEmpty {
                        if isSearching {
                            let totalSpacing: CGFloat = 16 * CGFloat(columnsCount + 1) // Spacing between items
                            let availableWidth = UIScreen.main.bounds.width - totalSpacing
                            let cellWidth = availableWidth / CGFloat(columnsCount)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnsCount), spacing: 16) {
                                ForEach(0..<columnsCount*4, id: \.self) { _ in
                                    SearchSkeletonCell(cellWidth: cellWidth)
                                }
                            }
                            .padding(.top)
                            .padding()
                        } else if hasNoResults {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No Results Found")
                                    .font(.headline)
                                Text("Try different keywords")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .padding(.top)
                        } else {
                            let totalSpacing: CGFloat = 16 * CGFloat(columnsCount + 1) // Spacing between items
                            let availableWidth = UIScreen.main.bounds.width - totalSpacing
                            let cellWidth = availableWidth / CGFloat(columnsCount)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnsCount), spacing: 16) {
                                ForEach(searchItems) { item in
                                    NavigationLink(destination: MediaInfoView(title: item.title, imageUrl: item.imageUrl, href: item.href, module: selectedModule!)) {
                                        VStack {
                                            KFImage(URL(string: item.imageUrl))
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(height: cellWidth * 3 / 2)
                                                .frame(maxWidth: cellWidth)
                                                .cornerRadius(10)
                                                .clipped()
                                            Text(item.title)
                                                .font(.subheadline)
                                                .foregroundColor(Color.primary)
                                                .padding([.leading, .bottom], 8)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .onAppear {
                                    updateOrientation()
                                }
                                .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                                    updateOrientation()
                                }
                            }
                            .padding(.top)
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
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
                    .id("moduleMenuHStack")
                    .fixedSize()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: selectedModuleId) { _ in
            if !searchText.isEmpty {
                performSearch()
            }
        }
        .onChange(of: searchText) { newValue in
            if newValue.isEmpty {
                searchItems = []
                hasNoResults = false
                isSearching = false
            }
        }
    }
    
    private func performSearch() {
        Logger.shared.log("Searching for: \(searchText)", type: "General")
        guard !searchText.isEmpty, let module = selectedModule else {
            searchItems = []
            hasNoResults = false
            return
        }
        
        isSearching = true
        hasNoResults = false
        searchItems = []
        
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
                    Logger.shared.log("Error loading module: \(error)", type: "Error")
                    isSearching = false
                    hasNoResults = true
                }
            }
        }
    }
    
    private func updateOrientation() {
        DispatchQueue.main.async {
            isLandscape = UIDevice.current.orientation.isLandscape
        }
    }
    
    private func determineColumns() -> Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return isLandscape ? mediaColumnsLandscape : mediaColumnsPortrait
        } else {
            return verticalSizeClass == .compact ? mediaColumnsLandscape : mediaColumnsPortrait
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
