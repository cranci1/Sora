//
//  SettingsViewGeneral.swift
//  Sora
//
//  Created by Francesco on 27/01/25.
//

import SwiftUI

fileprivate struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content
    
    init(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.footnote)
                .foregroundStyle(.gray)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                content
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.accentColor.opacity(0.3), location: 0),
                                .init(color: Color.accentColor.opacity(0), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .padding(.horizontal, 20)
            
            if let footer = footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
    }
}

fileprivate struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    var showDivider: Bool = true
    
    init(icon: String, title: String, isOn: Binding<Bool>, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self._isOn = isOn
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.primary)
                
                Text(title)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.accentColor.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
}

fileprivate struct SettingsPickerRow<T: Hashable>: View {
    let icon: String
    let title: String
    let options: [T]
    let optionToString: (T) -> String
    @Binding var selection: T
    var showDivider: Bool = true
    
    init(icon: String, title: String, options: [T], optionToString: @escaping (T) -> String, selection: Binding<T>, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self.options = options
        self.optionToString = optionToString
        self._selection = selection
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.primary)
                
                Text(title)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Menu {
                    ForEach(options, id: \.self) { option in
                        Button(action: { selection = option }) {
                            Text(optionToString(option))
                        }
                    }
                } label: {
                    Text(optionToString(selection))
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
}

struct SettingsViewGeneral: View {
    @AppStorage("episodeChunkSize") private var episodeChunkSize: Int = 100
    @AppStorage("fetchEpisodeMetadata") private var fetchEpisodeMetadata: Bool = true
    @AppStorage("analyticsEnabled") private var analyticsEnabled: Bool = false
    @AppStorage("hideSplashScreen") private var hideSplashScreenEnable: Bool = false
    @AppStorage("useNativeTabBar") private var useNativeTabBar: Bool = false
    @AppStorage("metadataProvidersOrderData") private var metadataProvidersOrderData: Data = {
        try! JSONEncoder().encode(["TMDB","AniList"])
    }()
    @AppStorage("tmdbImageWidth") private var TMDBimageWidht: String = "original"
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 2
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 4
    @AppStorage("metadataProviders") private var metadataProviders: String = "TMDB"
    @AppStorage("librarySectionsOrderData") private var librarySectionsOrderData: Data = {
        try! JSONEncoder().encode(["continueWatching", "continueReading", "collections"])
    }()
    @AppStorage("disabledLibrarySectionsData") private var disabledLibrarySectionsData: Data = {
        try! JSONEncoder().encode([String]())
    }()
    
    private var metadataProvidersOrder: [String] {
        get { (try? JSONDecoder().decode([String].self, from: metadataProvidersOrderData)) ?? ["AniList","TMDB"] }
        set { metadataProvidersOrderData = try! JSONEncoder().encode(newValue) }
    }

    private var librarySectionsOrder: [String] {
        get { (try? JSONDecoder().decode([String].self, from: librarySectionsOrderData)) ?? ["continueWatching", "continueReading", "collections"] }
        set { librarySectionsOrderData = try! JSONEncoder().encode(newValue) }
    }

    private var disabledLibrarySections: [String] {
        get { (try? JSONDecoder().decode([String].self, from: disabledLibrarySectionsData)) ?? [] }
        set { disabledLibrarySectionsData = try! JSONEncoder().encode(newValue) }
    }

    private let TMDBimageWidhtList = ["300", "500", "780", "1280", "original"]
    private let sortOrderOptions = ["Ascending", "Descending"]
    private let metadataProvidersList = ["TMDB", "AniList"]
    @EnvironmentObject var settings: Settings
    @State private var showRestartAlert = false

    private let isiOS26OrLater: Bool = {
        if #available(iOS 26, *) { return true } else { return false }
    }()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                SettingsSection(title: NSLocalizedString("Interface", comment: "")) {
                    SettingsPickerRow(
                        icon: "paintbrush",
                        title: NSLocalizedString("Appearance", comment: ""),
                        options: [Appearance.system, .light, .dark],
                        optionToString: { appearance in
                            switch appearance {
                            case .system: return NSLocalizedString("System", comment: "")
                            case .light: return NSLocalizedString("Light", comment: "")
                            case .dark: return NSLocalizedString("Dark", comment: "")
                            }
                        },
                        selection: $settings.selectedAppearance
                    )
                    
                    SettingsToggleRow(
                        icon: "wand.and.rays.inverse",
                        title: NSLocalizedString("Hide Splash Screen", comment: ""),
                        isOn: $hideSplashScreenEnable,
                        showDivider: isiOS26OrLater
                    )

                    if isiOS26OrLater {
                        SettingsToggleRow(
                            icon: "inset.filled.bottomthird.rectangle",
                            title: NSLocalizedString("Use Native Tab Bar", comment: ""),
                            isOn: $useNativeTabBar,
                            showDivider: false
                        )
                    }
                }
                
                SettingsSection(title: NSLocalizedString("Language", comment: "")) {
                    SettingsPickerRow(
                        icon: "globe",
                        title: NSLocalizedString("App Language", comment: ""),
                        options: [
                            "English",
                            "Arabic",
                            "Bosnian",
                            "Czech",
                            "Dutch",
                            "French",
                            "German",
                            "Italian",
                            "Kazakh",
                            "Mongolian",
                            "Norsk",
                            "Russian",
                            "Slovak",
                            "Spanish",
                            "Swedish"
                        ],
                        optionToString: { lang in
                            switch lang {
                            case "English": return "English"
                            case "Dutch": return "Nederlands"
                            case "French": return "Français"
                            case "German": return "Deutsch"
                            case "Arabic": return "العربية"
                            case "Bosnian": return "Bosanski"
                            case "Czech": return "Čeština"
                            case "Slovak": return "Slovenčina"
                            case "Spanish": return "Español"
                            case "Russian": return "Русский"
                            case "Norsk": return "Norsk"
                            case "Kazakh": return "Қазақша"
                            case "Mongolian": return "Монгол"
                            case "Swedish": return "Svenska"
                            case "Italian": return "Italiano"
                            default: return lang
                            }
                        },
                        selection: $settings.selectedLanguage,
                        showDivider: false
                    )
                    .onChange(of: settings.selectedLanguage) { _ in
                        showRestartAlert = true
                    }
                }
                
                SettingsSection(
                    title: NSLocalizedString("Media View", comment: ""),
                    footer: NSLocalizedString("The episode range controls how many episodes appear on each page. Episodes are grouped into sets (like 1–25, 26–50, and so on), allowing you to navigate through them more easily.\n\nFor episode metadata, it refers to the episode thumbnail and title, since sometimes it can contain spoilers.", comment: "")
                ) {
                    SettingsPickerRow(
                        icon: "list.number",
                        title: NSLocalizedString("Episodes Range", comment: ""),
                        options: [25, 50, 75, 100],
                        optionToString: { "\($0)" },
                        selection: $episodeChunkSize
                    )
                    
                    SettingsToggleRow(
                        icon: "info.circle",
                        title: NSLocalizedString("Fetch Episode metadata", comment: ""),
                        isOn: $fetchEpisodeMetadata
                    )
                    
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down")
                                .frame(width: 24, height: 24)
                                .foregroundStyle(.primary)
                            
                            Text(NSLocalizedString("Metadata Providers Order", comment: ""))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        List {
                            ForEach(Array(metadataProvidersOrder.enumerated()), id: \.element) { index, provider in
                                HStack {
                                    Text("\(index + 1)")
                                        .frame(width: 24, height: 24)
                                        .foregroundStyle(.gray)
                                    
                                    Text(provider)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.visible)
                                .listRowSeparatorTint(.gray.opacity(0.3))
                                .listRowInsets(EdgeInsets())
                            }
                            .onMove { from, to in
                                var arr = metadataProvidersOrder
                                arr.move(fromOffsets: from, toOffset: to)
                                metadataProvidersOrderData = try! JSONEncoder().encode(arr)
                            }
                        }
                        .listStyle(.plain)
                        .frame(height: CGFloat(metadataProvidersOrder.count * 65))
                        .background(Color.clear)
                        
                        Text(NSLocalizedString("Drag to reorder", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, -6)
                            .padding(.bottom, 8)
                    }
                    .environment(\.editMode, .constant(.active))
                }
                
                SettingsSection(
                    title: NSLocalizedString("Media Grid Layout", comment: ""),
                    footer: NSLocalizedString("Adjust the number of media items per row in portrait and landscape modes.", comment: "")
                ) {
                    SettingsPickerRow(
                        icon: "rectangle.portrait",
                        title: NSLocalizedString("Portrait Columns", comment: ""),
                        options: UIDevice.current.userInterfaceIdiom == .pad ? Array(1...5) : Array(1...4),
                        optionToString: { "\($0)" },
                        selection: $mediaColumnsPortrait
                    )
                    
                    SettingsPickerRow(
                        icon: "rectangle",
                        title: NSLocalizedString("Landscape Columns", comment: ""),
                        options: UIDevice.current.userInterfaceIdiom == .pad ? Array(2...8) : Array(2...5),
                        optionToString: { "\($0)" },
                        selection: $mediaColumnsLandscape,
                        showDivider: false
                    )
                }
                

                
                SettingsSection(
                    title: NSLocalizedString("Advanced", comment: ""),
                    footer: NSLocalizedString("Anonymous data is collected to improve the app. No personal information is collected. This can be disabled at any time.", comment: "")
                ) {
                    SettingsToggleRow(
                        icon: "chart.bar",
                        title: NSLocalizedString("Enable Analytics", comment: ""),
                        isOn: $analyticsEnabled,
                        showDivider: false
                    )
                }
                
                SettingsSection(
                    title: NSLocalizedString("Library View", comment: ""),
                    footer: NSLocalizedString("Customize the sections shown in your library. You can reorder sections or disable them completely.", comment: "")
                ) {
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down")
                                .frame(width: 24, height: 24)
                                .foregroundStyle(.primary)
                            
                            Text(NSLocalizedString("Library Sections Order", comment: ""))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        List {
                            ForEach(Array(librarySectionsOrder.enumerated()), id: \.element) { index, section in
                                HStack {
                                    Text("\(index + 1)")
                                        .frame(width: 24, height: 24)
                                        .foregroundStyle(.gray)
                                    
                                    Image(systemName: sectionIcon(for: section))
                                        .frame(width: 24, height: 24)
                                    
                                    Text(sectionName(for: section))
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: toggleBinding(for: section))
                                    .labelsHidden()
                                    .tint(.accentColor.opacity(0.7))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.visible)
                                .listRowSeparatorTint(.gray.opacity(0.3))
                                .listRowInsets(EdgeInsets())
                            }
                            .onMove { from, to in
                                var arr = librarySectionsOrder
                                arr.move(fromOffsets: from, toOffset: to)
                                librarySectionsOrderData = try! JSONEncoder().encode(arr)
                            }
                        }
                        .listStyle(.plain)
                        .frame(height: CGFloat(librarySectionsOrder.count * 70))
                        .background(Color.clear)
                        
                        Text(NSLocalizedString("Drag to reorder sections", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, -6)
                            .padding(.bottom, 8)
                    }
                    .environment(\.editMode, .constant(.active))
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle(NSLocalizedString("General", comment: ""))
        .scrollViewBottomPadding()
        .alert(isPresented: $showRestartAlert) {
            Alert(
                title: Text(verbatim: "Restart Required"),
                message: Text(verbatim: "Please restart the app to apply the language change."),
                dismissButton: .default(Text(verbatim: "OK"))
            )
        }
    }
    
    private func sectionName(for section: String) -> String {
        switch section {
        case "continueWatching":
            return NSLocalizedString("Continue Watching", comment: "")
        case "continueReading":
            return NSLocalizedString("Continue Reading", comment: "")
        case "collections":
            return NSLocalizedString("Collections", comment: "")
        default:
            return section
        }
    }
    
    private func sectionIcon(for section: String) -> String {
        switch section {
        case "continueWatching":
            return "play.fill"
        case "continueReading":
            return "book.fill"
        case "collections":
            return "folder.fill"
        default:
            return "questionmark"
        }
    }
    
    private func toggleBinding(for section: String) -> Binding<Bool> {
        return Binding(
            get: { !self.disabledLibrarySections.contains(section) },
            set: { isEnabled in
                var sections = self.disabledLibrarySections
                if isEnabled {
                    sections.removeAll { $0 == section }
                } else {
                    if !sections.contains(section) {
                        sections.append(section)
                    }
                }
                self.disabledLibrarySectionsData = try! JSONEncoder().encode(sections)
            }
        )
    }
}
