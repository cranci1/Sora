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
    @AppStorage("refreshModulesOnLaunch") private var refreshModulesOnLaunch: Bool = false
    @AppStorage("fetchEpisodeMetadata") private var fetchEpisodeMetadata: Bool = true
    @AppStorage("analyticsEnabled") private var analyticsEnabled: Bool = false
    @AppStorage("multiThreads") private var multiThreadsEnabled: Bool = false
    @AppStorage("metadataProviders") private var metadataProviders: String = "AniList"
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 2
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 4
    @AppStorage("currentAppIcon") private var currentAppIcon = "Default"
    @AppStorage("episodeSortOrder") private var episodeSortOrder: String = "Ascending"
    
    private let metadataProvidersList = ["AniList"]
    private let sortOrderOptions = ["Ascending", "Descending"]
    @EnvironmentObject var settings: Settings
    @State private var showAppIconPicker = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsSection(title: "Interface") {
                    SettingsPickerRow(
                        icon: "paintbrush",
                        title: "Appearance",
                        options: [Appearance.system, .light, .dark],
                        optionToString: { appearance in
                            switch appearance {
                            case .system: return "System"
                            case .light: return "Light"
                            case .dark: return "Dark"
                            }
                        },
                        selection: $settings.selectedAppearance
                    )
                    
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "app")
                                .frame(width: 24, height: 24)
                                .foregroundStyle(.primary)
                            
                            Text("App Icon")
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                showAppIconPicker = true
                            }) {
                                Text(currentAppIcon)
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                
                SettingsSection(
                    title: "Media View",
                    footer: "The episode range controls how many episodes appear on each page. Episodes are grouped into sets (like 1–25, 26–50, and so on), allowing you to navigate through them more easily.\n\nFor episode metadata, it refers to the episode thumbnail and title, since sometimes it can contain spoilers."
                ) {
                    SettingsPickerRow(
                        icon: "list.number",
                        title: "Episodes Range",
                        options: [25, 50, 75, 100],
                        optionToString: { "\($0)" },
                        selection: $episodeChunkSize
                    )
                    
                    SettingsToggleRow(
                        icon: "info.circle",
                        title: "Fetch Episode metadata",
                        isOn: $fetchEpisodeMetadata
                    )
                    
                    SettingsPickerRow(
                        icon: "server.rack",
                        title: "Metadata Provider",
                        options: metadataProvidersList,
                        optionToString: { $0 },
                        selection: $metadataProviders,
                        showDivider: false
                    )
                }
                
                SettingsSection(
                    title: "Media Grid Layout",
                    footer: "Adjust the number of media items per row in portrait and landscape modes."
                ) {
                    SettingsPickerRow(
                        icon: "rectangle.portrait",
                        title: "Portrait Columns",
                        options: UIDevice.current.userInterfaceIdiom == .pad ? Array(1...5) : Array(1...4),
                        optionToString: { "\($0)" },
                        selection: $mediaColumnsPortrait
                    )
                    
                    SettingsPickerRow(
                        icon: "rectangle",
                        title: "Landscape Columns",
                        options: UIDevice.current.userInterfaceIdiom == .pad ? Array(2...8) : Array(2...5),
                        optionToString: { "\($0)" },
                        selection: $mediaColumnsLandscape,
                        showDivider: false
                    )
                }
                
                SettingsSection(
                    title: "Modules",
                    footer: "Note that the modules will be replaced only if there is a different version string inside the JSON file."
                ) {
                    SettingsToggleRow(
                        icon: "arrow.clockwise",
                        title: "Refresh Modules on Launch",
                        isOn: $refreshModulesOnLaunch,
                        showDivider: false
                    )
                }
                
                SettingsSection(
                    title: "Advanced",
                    footer: "Anonymous data is collected to improve the app. No personal information is collected. This can be disabled at any time."
                ) {
                    SettingsToggleRow(
                        icon: "chart.bar",
                        title: "Enable Analytics",
                        isOn: $analyticsEnabled,
                        showDivider: false
                    )
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("General")
        .scrollViewBottomPadding()
        .sheet(isPresented: $showAppIconPicker) {
            if #available(iOS 16.0, *) {
                SettingsViewAlternateAppIconPicker(isPresented: $showAppIconPicker)
                    .presentationDetents([.height(200)])
            } else {
                SettingsViewAlternateAppIconPicker(isPresented: $showAppIconPicker)
            }
        }
    }
}
