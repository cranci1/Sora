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

struct ModuleButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(PlainButtonStyle())
            .offset(y: 45)
            .zIndex(999)
    }
}

struct SearchView: View {
    @AppStorage("selectedModuleId") private var selectedModuleId: String?
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 2
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 4
    
    @StateObject private var jsController = JSController.shared
    @EnvironmentObject var moduleManager: ModuleManager
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @Binding public var searchQuery: String
    
    @State private var searchItems: [SearchItem] = []
    @State private var selectedSearchItem: SearchItem?
    @State private var isSearching = false
    @State private var hasNoResults = false
    @State private var isLandscape: Bool = UIDevice.current.orientation.isLandscape
    @State private var isModuleSelectorPresented = false
    
    init(searchQuery: Binding<String>) {
        self._searchQuery = searchQuery
    }
    
    private var selectedModule: ScrapingModule? {
        guard let id = selectedModuleId else { return nil }
        return moduleManager.modules.first { $0.id.uuidString == id }
    }
    
    private var columnsCount: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let isLandscape = UIScreen.main.bounds.width > UIScreen.main.bounds.height
            return isLandscape ? mediaColumnsLandscape : mediaColumnsPortrait
        } else {
            return verticalSizeClass == .compact ? mediaColumnsLandscape : mediaColumnsPortrait
        }
    }
    
    private var cellWidth: CGFloat {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) }
            .first
        let safeAreaInsets = keyWindow?.safeAreaInsets ?? .zero
        let safeWidth = UIScreen.main.bounds.width - safeAreaInsets.left - safeAreaInsets.right
        let totalSpacing: CGFloat = 16 * CGFloat(columnsCount + 1)
        let availableWidth = safeWidth - totalSpacing
        return availableWidth / CGFloat(columnsCount)
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                HStack {
                    Text("Search")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Menu {
                        ForEach(getModuleLanguageGroups(), id: \.self) { language in
                            Menu(language) {
                                ForEach(getModulesForLanguage(language), id: \.id) { module in
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
                                            if module.id.uuidString == selectedModuleId {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        if let selectedModule = selectedModule {
                            KFImage(URL(string: selectedModule.metadata.iconUrl))
                                .resizable()
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "questionmark.app.fill")
                                .resizable()
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                ScrollView {
                    let columnsCount = determineColumns()
                    VStack(spacing: 0) {
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
                        
                        if !searchQuery.isEmpty {
                            if isSearching {
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
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: selectedModuleId) { _ in
            if !searchQuery.isEmpty {
                performSearch()
            }
        }
        .onChange(of: moduleManager.selectedModuleChanged) { _ in
            if moduleManager.selectedModuleChanged {
                if selectedModuleId == nil && !moduleManager.modules.isEmpty {
                    selectedModuleId = moduleManager.modules[0].id.uuidString
                }
                moduleManager.selectedModuleChanged = false
            }
        }
        .onChange(of: searchQuery) { newValue in
            if newValue.isEmpty {
                searchItems = []
                hasNoResults = false
                isSearching = false
            } else {
                performSearch()
            }
        }
        .onAppear {
            if !searchQuery.isEmpty {
                performSearch()
            }
        }
    }
    
    private func performSearch() {
        Logger.shared.log("Searching for: \(searchQuery)", type: "General")
        guard !searchQuery.isEmpty, let module = selectedModule else {
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
                        jsController.fetchJsSearchResults(keyword: searchQuery, module: module) { items in
                            searchItems = items
                            hasNoResults = items.isEmpty
                            isSearching = false
                        }
                    } else {
                        jsController.fetchSearchResults(keyword: searchQuery, module: module) { items in
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
            if result[language] == nil {
                result[language] = [module]
            } else {
                result[language]?.append(module)
            }
        }
        
        return result
    }
    
    private func getModuleLanguageGroups() -> [String] {
        return getModulesByLanguage().keys.sorted()
    }
    
    private func getModulesForLanguage(_ language: String) -> [ScrapingModule] {
        return getModulesByLanguage()[language] ?? []
    }
}

struct SearchBar: View {
    @State private var debounceTimer: Timer?
    @Binding var text: String
    var onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            TextField("Search...", text: $text, onCommit: onSearchButtonClicked)
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .onChange(of: text){newValue in
                    debounceTimer?.invalidate()
                    debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                        onSearchButtonClicked()
                    }
                }
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
