//
//  SettingsViewGeneral.swift
//  Sora
//
//  Created by Francesco on 27/01/25.
//

import SwiftUI

struct SettingsViewGeneral: View {
    @AppStorage("episodeChunkSize") private var episodeChunkSize = 100
    @AppStorage("refreshModulesOnLaunch") private var refreshModulesOnLaunch = false
    @AppStorage("fetchEpisodeMetadata") private var fetchEpisodeMetadata = true
    @AppStorage("analyticsEnabled") private var analyticsEnabled = false
    @AppStorage("multiThreads") private var multiThreadsEnabled = false
    @AppStorage("metadataProviders") private var metadataProviders = "AniList"
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait = 2
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape = 4
    @AppStorage("hideEmptySections") private var hideEmptySections = false
    @AppStorage("currentAppIcon") private var currentAppIcon = "Default"
    @AppStorage("episodeSortOrder") private var episodeSortOrder = "Ascending"

    private let metadataProvidersList = ["AniList"]
    private let sortOrderOptions = ["Ascending", "Descending"]
    @EnvironmentObject var settings: Settings
    @State private var showAppIconPicker = false

    var body: some View {
        Form {
            Section(header: Text("Interface")) {
                ColorPicker("Accent Color", selection: $settings.accentColor)
                HStack {
                    Text("Appearance")
                    Spacer()
                    Menu {
                        ForEach(Appearance.allCases) { appearance in
                            Button {
                                settings.selectedAppearance = appearance
                            } label: {
                                Label(appearance.rawValue.capitalized, systemImage: settings.selectedAppearance == appearance ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Text(settings.selectedAppearance.rawValue.capitalized)
                    }
                }
                HStack {
                    Text("App Icon")
                    Spacer()
                    Button(action: {
                        showAppIconPicker.toggle()
                    }) {
                        Text(currentAppIcon.isEmpty ? "Default" : currentAppIcon)
                            .font(.body)
                            .foregroundColor(.accentColor)
                    }
                }
                HStack {
                    Text("Loading Animation")
                    Spacer()
                    Menu {
                        ForEach(ShimmerType.allCases) { shimmerType in
                            Button {
                                settings.shimmerType = shimmerType
                            } label: {
                                Label(shimmerType.rawValue.capitalized, systemImage: settings.shimmerType == shimmerType ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Text(settings.shimmerType.rawValue.capitalized)
                    }
                }
                Toggle("Hide Empty Sections", isOn: $hideEmptySections)
                    .tint(.accentColor)
            }

            Section(header: Text("Media View"), footer: Text("The episode range controls how many episodes appear on each page. Episodes are grouped into sets (like 1-25, 26-50, and so on), allowing you to navigate through them more easily.\n\nFor episode metadata it is refering to the episode thumbnail and title, since sometimes it can contain spoilers.")) {
                HStack {
                    Text("Episodes Range")
                    Spacer()
                    Menu("\(episodeChunkSize)") {
                        ForEach([25, 50, 75, 100], id: \.self) { chunkSize in
                            Button(action: {
                                episodeChunkSize = chunkSize
                            }) {
                                if episodeChunkSize == chunkSize {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .accessibilityLabel("Checkmark Icon")
                                }
                                Text("\(chunkSize)")
                            }
                        }
                    }
                }

                Toggle("Fetch Episode metadata", isOn: $fetchEpisodeMetadata)
                    .tint(.accentColor)

                HStack {
                    Text("Metadata Provider")
                    Spacer()
                    Menu(metadataProviders) {
                        ForEach(metadataProvidersList, id: \.self) { provider in
                            Button(action: {
                                metadataProviders = provider
                            }) {
                                if provider == metadataProviders {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .accessibilityLabel("Checkmark Icon")
                                }
                                Text(provider)
                            }
                        }
                    }
                }
            }

            Section(header: Text("Media Grid Layout"), footer: Text("Adjust the number of media items per row in portrait and landscape modes.")) {
                HStack {
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Picker("Portrait Columns", selection: $mediaColumnsPortrait) {
                            ForEach(1..<6) { i in Text("\(i)").tag(i) }
                        }
                        .pickerStyle(MenuPickerStyle())
                    } else {
                        Picker("Portrait Columns", selection: $mediaColumnsPortrait) {
                            ForEach(1..<5) { i in Text("\(i)").tag(i) }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                HStack {
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Picker("Landscape Columns", selection: $mediaColumnsLandscape) {
                            ForEach(2..<9) { i in Text("\(i)").tag(i) }
                        }
                        .pickerStyle(MenuPickerStyle())
                    } else {
                        Picker("Landscape Columns", selection: $mediaColumnsLandscape) {
                            ForEach(2..<6) { i in Text("\(i)").tag(i) }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
            }

            Section(header: Text("Modules"), footer: Text("Note that the modules will be replaced only if there is a different version string inside the JSON file.")) {
                Toggle("Refresh Modules on Launch", isOn: $refreshModulesOnLaunch)
                    .tint(.accentColor)
            }

            Section(header: Text("Advanced"), footer: Text("Anonymous data is collected to improve the app. No personal information is collected. This can be disabled at any time.")) {
                Toggle("Enable Analytics", isOn: $analyticsEnabled)
                    .tint(.accentColor)
            }
        }
        .navigationTitle("General")
        .sheet(isPresented: $showAppIconPicker) {
            if #available(iOS 16.0, *) {
                    SettingsViewAlternateAppIconPicker(isPresented: $showAppIconPicker)
                        .presentationDetents([.height(200)])
                } else {
                    SettingsViewAlternateAppIconPicker(isPresented: $showAppIconPicker)
                }
        }
        .modifier(HideToolbarModifier())
    }
}
