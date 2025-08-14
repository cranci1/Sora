//
//  SearchView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI

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
    @AppStorage("useNativeTabBar") private var useNativeTabBar: Bool = false
    
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
    @State private var searchHistory: [String] = []
    @State private var isSearchFieldFocused = false
    @State private var saveDebounceTimer: Timer?
    @State private var searchDebounceTimer: Timer?
    @State private var isActive: Bool = false
    
    init(searchQuery: Binding<String>) {
        self._searchQuery = searchQuery
    }
    
    private var selectedModule: ScrapingModule? {
        guard let id = selectedModuleId else { return nil }
        return moduleManager.modules.first { $0.id.uuidString == id }
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]
    
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
    
    private var mainContent: some View {
            VStack(alignment: .leading) {
                HStack {
                    Text(LocalizedStringKey("Search"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
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
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                if useNativeTabBar {
                    SearchBar(text: $searchQuery, isSearching: $isSearching)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                }
                
                ScrollView(showsIndicators: false) {
                    SearchContent(
                        selectedModule: selectedModule,
                        searchQuery: searchQuery,
                        searchHistory: searchHistory,
                        searchItems: searchItems,
                        isSearching: isSearching,
                        hasNoResults: hasNoResults,
                        columns: columns,
                        columnsCount: columnsCount,
                        cellWidth: cellWidth,
                        onHistoryItemSelected: { query in
                            searchQuery = query
                            searchDebounceTimer?.invalidate()
                            
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            NotificationCenter.default.post(name: .tabBarSearchQueryUpdated, object: nil, userInfo: ["searchQuery": query])
                            
                            performSearch()
                        },
                        onHistoryItemDeleted: { index in
                            removeFromHistory(at: index)
                        },
                        onClearHistory: clearSearchHistory
                    )
                }
                .scrollViewBottomPadding()
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                )
            }
            .scrollViewBottomPadding()
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            )
        }
    
    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    mainContent
                }
            } else {
                NavigationView {
                    mainContent
                }
                .navigationViewStyle(.stack)
            }
        }
        .onAppear {
            isActive = true
            loadSearchHistory()
            if !searchQuery.isEmpty {
                performSearch()
            }
            let isMediaInfoActive = UserDefaults.standard.bool(forKey: "isMediaInfoActive")
            let isReaderActive = UserDefaults.standard.bool(forKey: "isReaderActive")
            if !isMediaInfoActive && !isReaderActive {
                NotificationCenter.default.post(name: .showTabBar, object: nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                let isMediaInfoActive = UserDefaults.standard.bool(forKey: "isMediaInfoActive")
                let isReaderActive = UserDefaults.standard.bool(forKey: "isReaderActive")
                if !isMediaInfoActive && !isReaderActive {
                    NotificationCenter.default.post(name: .showTabBar, object: nil)
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: .searchQueryChanged,
                object: nil,
                queue: .main
            ) { notification in
                if let query = notification.userInfo?["searchQuery"] as? String {
                    searchQuery = query
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .searchQueryChanged, object: nil)
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            let isMediaInfoActive = UserDefaults.standard.bool(forKey: "isMediaInfoActive")
            let isReaderActive = UserDefaults.standard.bool(forKey: "isReaderActive")
            if isActive && !isMediaInfoActive && !isReaderActive {
                NotificationCenter.default.post(name: .showTabBar, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            isActive = true
            let isMediaInfoActive = UserDefaults.standard.bool(forKey: "isMediaInfoActive")
            let isReaderActive = UserDefaults.standard.bool(forKey: "isReaderActive")
            if !isMediaInfoActive && !isReaderActive {
                NotificationCenter.default.post(name: .showTabBar, object: nil)
            }
        }
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
            searchDebounceTimer?.invalidate()
            
            if newValue.isEmpty {
                saveDebounceTimer?.invalidate()
                searchItems = []
                hasNoResults = false
                isSearching = false
            } else {
                searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { _ in
                    performSearch()
                }
                
                saveDebounceTimer?.invalidate()
                saveDebounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                    self.addToSearchHistory(newValue)
                }
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
        
        isSearchFieldFocused = false
        
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
                            DispatchQueue.main.async {
                                searchItems = items
                                hasNoResults = items.isEmpty
                                isSearching = false
                            }
                        }
                    } else {
                        jsController.fetchSearchResults(keyword: searchQuery, module: module) { items in
                            DispatchQueue.main.async {
                                searchItems = items
                                hasNoResults = items.isEmpty
                                isSearching = false
                            }
                        }
                    }
                } catch {
                    Logger.shared.log("Error loading module: \(error)", type: "Error")
                    DispatchQueue.main.async {
                        isSearching = false
                        hasNoResults = true
                    }
                }
            }
        }
    }
    
    private func loadSearchHistory() {
        searchHistory = UserDefaults.standard.stringArray(forKey: "searchHistory") ?? []
    }
    
    private func saveSearchHistory() {
        UserDefaults.standard.set(searchHistory, forKey: "searchHistory")
    }
    
    private func addToSearchHistory(_ term: String) {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else { return }
        
        searchHistory.removeAll { $0.lowercased() == trimmedTerm.lowercased() }
        searchHistory.insert(trimmedTerm, at: 0)
        
        if searchHistory.count > 10 {
            searchHistory = Array(searchHistory.prefix(10))
        }
        
        saveSearchHistory()
    }
    
    private func removeFromHistory(at index: Int) {
        guard index < searchHistory.count else { return }
        searchHistory.remove(at: index)
        saveSearchHistory()
    }
    
    private func clearSearchHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
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
