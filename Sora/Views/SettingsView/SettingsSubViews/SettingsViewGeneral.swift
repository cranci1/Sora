//
//  SettingsViewGeneral.swift
//  Sora
//
//  Created by Francesco on 27/01/25.
//

import SwiftUI

struct SettingsViewGeneral: View {
    @AppStorage("episodeChunkSize") private var episodeChunkSize: Int = 100
    @AppStorage("refreshModulesOnLaunch") private var refreshModulesOnLaunch: Bool = false
    @AppStorage("fetchEpisodeMetadata") private var fetchEpisodeMetadata: Bool = true
    @AppStorage("analyticsEnabled") private var analyticsEnabled: Bool = false
    @AppStorage("multiThreads") private var multiThreadsEnabled: Bool = false
    @AppStorage("metadataProviders") private var metadataProviders: String = "AniList"
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 2
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 4
    
    private let metadataProvidersList = ["AniList"]
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        Form {
            Section(header: Text("Interface")) {
                ColorPicker("Accent Color", selection: $settings.accentColor)
                HStack {
                    Text("Appearance")
                    Picker("Appearance", selection: $settings.selectedAppearance) {
                        Text("System").tag(Appearance.system)
                        Text("Light").tag(Appearance.light)
                        Text("Dark").tag(Appearance.dark)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            
            Section(header: Text("Media View"), footer: Text("The episode range controls how many episodes appear on each page. Episodes are grouped into sets (like 1-25, 26-50, and so on), allowing you to navigate through them more easily.\n\nFor episode metadata it is refering to the episode thumbnail and title, since sometimes it can contain spoilers.")) {
                HStack {
                    Text("Episodes Range")
                    Spacer()
                    Menu {
                        Button(action: { episodeChunkSize = 25 }) { Text("25") }
                        Button(action: { episodeChunkSize = 50 }) { Text("50") }
                        Button(action: { episodeChunkSize = 75 }) { Text("75") }
                        Button(action: { episodeChunkSize = 100 }) { Text("100") }
                    } label: {
                        Text("\(episodeChunkSize)")
                    }
                }
                Toggle("Fetch Episode metadata", isOn: $fetchEpisodeMetadata)
                    .tint(.accentColor)
                HStack {
                    Text("Metadata Provider")
                    Spacer()
                    Menu(metadataProviders) {
                        ForEach(metadataProvidersList, id: \.self) { provider in
                            Button(action: { metadataProviders = provider }) {
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
    }
}
