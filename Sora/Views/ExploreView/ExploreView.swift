//
//  LibraryView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher

struct ExploreView: View {
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var moduleManager: ModuleManager
    @EnvironmentObject private var profileStore: ProfileStore

    @AppStorage("selectedModuleId") private var selectedModuleId: String?
    @AppStorage("hideEmptySections") private var hideEmptySections: Bool?
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 2
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 4
    
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @State private var continueWatchingItems: [ContinueWatchingItem] = []
    @State private var isLandscape: Bool = UIDevice.current.orientation.isLandscape
    @State private var showProfileSettings = false

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
    
    var body: some View {
        NavigationView {
            ScrollView {
                let columnsCount = determineColumns()

                VStack(alignment: .leading, spacing: 12) {
                    if hideEmptySections != true || !libraryManager.bookmarks.isEmpty {
                        Text("Continue Watching")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal, 20)

                        if continueWatchingItems.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "play.circle")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No items to continue watching.")
                                    .font(.headline)
                                Text("Recently watched content will appear here.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        } else {
                            ContinueWatchingSection(items: $continueWatchingItems, markAsWatched: { item in
                                markContinueWatchingItemAsWatched(item: item)
                            }, removeItem: { item in
                                removeContinueWatchingItem(item: item)
                            })
                        }
                    }

                    if !(hideEmptySections ?? false) && libraryManager.bookmarks.isEmpty {
                        Text("Bookmarks")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal, 20)

                        if libraryManager.bookmarks.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magazine")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("You have no items saved.")
                                    .font(.headline)
                                Text("Bookmark items for an easier access later.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columnsCount), spacing: 12) {
                                ForEach(libraryManager.bookmarks) { item in
                                    if let module = moduleManager.modules.first(where: { $0.id.uuidString == item.moduleId }) {
                                        NavigationLink(destination: MediaInfoView(title: item.title, imageUrl: item.imageUrl, href: item.href, module: module)) {
                                            VStack(alignment: .leading) {
                                                ZStack {
                                                    KFImage(URL(string: item.imageUrl))
                                                        .placeholder {
                                                            RoundedRectangle(cornerRadius: 10)
                                                                .fill(Color.gray.opacity(0.3))
                                                                .aspectRatio(2/3, contentMode: .fit)
                                                                .shimmering()
                                                        }
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(height: cellWidth * 3 / 2)
                                                        .frame(maxWidth: cellWidth)
                                                        .cornerRadius(10)
                                                        .clipped()
                                                        .overlay(
                                                            KFImage(URL(string: module.metadata.iconUrl))
                                                                .resizable()
                                                                .frame(width: 24, height: 24)
                                                                .cornerRadius(4)
                                                                .padding(4),
                                                            alignment: .topLeading
                                                        )
                                                }
                                                Text(item.title)
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                    .multilineTextAlignment(.leading)
                                            }
                                        }
                                        .contextMenu {
                                            Button(role: .destructive, action: {
                                                libraryManager.removeBookmark(item: item)
                                            }) {
                                                Label("Remove from Bookmarks", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 20)

                NavigationLink(
                    destination: SettingsViewProfile(),
                    isActive: $showProfileSettings,
                    label: { EmptyView() }
                )
                .hidden()
            }
            .navigationTitle("Explore")
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
                        HStack(spacing: 4) {
                            if let selectedModule = selectedModule {
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
                        }
                    }
                    .fixedSize()
                }
            }
        }
                .navigationViewStyle(StackNavigationViewStyle())
                .onAppear {
                    updateOrientation()
                    fetchContinueWatching()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                    updateOrientation()
                }
    }
    
    private func fetchContinueWatching() {
        continueWatchingItems = ContinueWatchingManager.shared.fetchItems()
    }
    
    private func markContinueWatchingItemAsWatched(item: ContinueWatchingItem) {
        let key = "lastPlayedTime_\(item.fullUrl)"
        let totalKey = "totalTime_\(item.fullUrl)"
        UserDefaults.standard.set(99999999.0, forKey: key)
        UserDefaults.standard.set(99999999.0, forKey: totalKey)
        ContinueWatchingManager.shared.remove(item: item)
        continueWatchingItems.removeAll { $0.id == item.id }
    }
    
    private func removeContinueWatchingItem(item: ContinueWatchingItem) {
        ContinueWatchingManager.shared.remove(item: item)
        continueWatchingItems.removeAll { $0.id == item.id }
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
