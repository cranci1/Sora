//
//  SearchView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import Kingfisher
import SwiftUI

struct SearchItem: Identifiable {
    let id = UUID()
    let title: String
    let imageUrl: String
    let href: String
}

struct SearchView: View {
    @AppStorage("hideEmptySections") private var hideEmptySections: Bool?
    @AppStorage("selectedModuleId") private var selectedModuleId: String?
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait = 2
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape = 4

    @StateObject private var jsController = JSController()
    @EnvironmentObject private var moduleManager: ModuleManager
    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @State private var searchItems: [SearchItem] = []
    @State private var selectedSearchItem: SearchItem?
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var hasNoResults = false
    @State private var isLandscape: Bool = UIDevice.current.orientation.isLandscape
    @State private var isModuleSelectorPresented = false
    @State private var showProfileSettings = false
    @State private var showModuleSettings = false

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

                    if !(hideEmptySections ?? false) && selectedModule == nil {
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.app")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                                .accessibilityLabel("Questionmark Icon")
                            Text("No Module Selected")
                                .font(.headline)
                            Text("Please select a module from settings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                    }

                    if !searchText.isEmpty {
                        if isSearching {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnsCount), spacing: 16) {
                                ForEach(0 ..< columnsCount * 4, id: \.self) { _ in
                                    SkeletonCell(type: .search, cellWidth: cellWidth)
                                }
                            }
                            .padding(.top)
                            .padding()
                        } else if hasNoResults {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                    .accessibilityLabel("Magnifying Glass Icon")
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

                NavigationLink(
                    destination: SettingsViewProfile(),
                    isActive: $showProfileSettings,
                    label: { EmptyView() }
                )
                .hidden()

                NavigationLink(
                    destination: SettingsViewModule(),
                    isActive: $showModuleSettings,
                    label: { EmptyView() }
                )
                .hidden()
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(profileStore.profiles) { profile in
                            Button {
                                profileStore.setCurrentProfile(profile)
                            } label: {
                                if profile == profileStore.currentProfile {
                                    Label("\(profile.emoji) \(profile.name)", systemImage: "checkmark")
                                } else {
                                    Text("\(profile.emoji) \(profile.name)")
                                }
                            }
                        }

                        Divider()

                        Button {
                            showProfileSettings = true
                        } label: {
                            Label("Edit Profiles", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        Circle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(profileStore.currentProfile.emoji)
                                    .font(.system(size: 20))
                                    .foregroundStyle(.primary)
                            )
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if getModuleLanguageGroups().isEmpty {
                            Button("No modules available") {
                                print("[Error] No Modules Button clicked")
                            }
                                .disabled(true)

                            Divider()

                            Button {
                                showModuleSettings = true
                            } label: {
                                Label("Add Modules", systemImage: "plus.app")
                            }
                        } else {
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
                                                        .accessibilityLabel("Checkmark Icon")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if let selectedModule {
                                Text(selectedModule.metadata.sourceName)
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Select Module")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                            }
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                                .accessibilityLabel("Expand Icon")
                        }
                    }
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

    private func cleanLanguageName(_ language: String?) -> String {
        guard let language else { return "Unknown" }

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
        getModulesByLanguage().keys.sorted()
    }

    private func getModulesForLanguage(_ language: String) -> [ScrapingModule] {
        getModulesByLanguage()[language] ?? []
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
                .onChange(of: text) {_ in
                    debounceTimer?.invalidate()
                    // Start a new timer to wait before performing the action
                    debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                        // Perform the action after the delay (debouncing)
                        onSearchButtonClicked()
                    }
                }
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                            .accessibilityLabel("Search Icon")
                        if !text.isEmpty {
                            Button(action: {
                                text = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.secondary)
                                    .padding(.trailing, 8)
                                    .accessibilityLabel("Clear Icon")
                            }
                        }
                    }
                )
        }
    }
}
