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
                VStack(alignment: .leading, spacing: 12) {
                    //TODO: add explore content views
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
                    //TODO: fetch explore content here
                }
                .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                    updateOrientation()
                }
    }
    
    private func updateOrientation() {
        DispatchQueue.main.async {
            isLandscape = UIDevice.current.orientation.isLandscape
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
