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
    @AppStorage("CustomDNSProvider") private var customDNSProvider: String = "Cloudflare"
    @AppStorage("customPrimaryDNS") private var customPrimaryDNS: String = ""
    @AppStorage("customSecondaryDNS") private var customSecondaryDNS: String = ""
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 2
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 4
    
    private let customDNSProviderList = ["Cloudflare", "Google", "OpenDNS", "Quad9", "AdGuard", "CleanBrowsing", "ControlD", "Custom"]
    private let metadataProvidersList = ["AniList"]
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Form {
            Section(header: Text("Interface")) {
                HStack {
                    Text("Appearance")
                    Picker("Appearance", selection: $settings.selectedAppearance) {
                        Text("System").tag(Appearance.system)
                        Text("Light").tag(Appearance.light)
                        Text("Dark").tag(Appearance.dark)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.vertical, 6)
            }
            
            Section(header: Text("Media View"), footer: Text("The episode range controls how many episodes appear on each page. Episodes are grouped into sets (like 1-25, 26-50, and so on), allowing you to navigate through them more easily.\n\nFor episode metadata it is referring to the episode thumbnail and title, since sometimes it can contain spoilers.")) {
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
                .padding(.vertical, 6)
                
                Toggle("Fetch Episode metadata", isOn: $fetchEpisodeMetadata)
                    .padding(.vertical, 6)
                
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
                .padding(.vertical, 6)
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
                .padding(.vertical, 6)
                
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
                .padding(.vertical, 6)
            }
            
            Section(header: Text("Modules"), footer: Text("Note that the modules will be replaced only if there is a different version string inside the JSON file.")) {
                Toggle("Refresh Modules on Launch", isOn: $refreshModulesOnLaunch)
                    .tint(.accentColor)
                    .padding(.vertical, 6)
            }
            
            Section(header: Text("Advanced"), footer: Text("Anonymous data is collected to improve the app. No personal information is collected. This can be disabled at any time.")) {
                Toggle("Enable Analytics", isOn: $analyticsEnabled)
                    .padding(.vertical, 6)
            }
        }
        .background(
            ZStack {
                Color(.systemBackground)
                    .opacity(0.95)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: colorScheme == .dark ? Color(.label).opacity(0.1) : Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 75)
        .frame(minHeight: 600)
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
    }
}
