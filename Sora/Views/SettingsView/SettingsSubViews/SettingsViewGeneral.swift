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
    @AppStorage("analyticsEnabled") private var analyticsEnabled: Bool = true
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        Form {
            Section(header: Text("Interface")) {
                ColorPicker("Accent Color", selection: $settings.accentColor)
                HStack() {
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
                        Button(action: { episodeChunkSize = 25 }) {
                            Text("25")
                        }
                        Button(action: { episodeChunkSize = 50 }) {
                            Text("50")
                        }
                        Button(action: { episodeChunkSize = 75 }) {
                            Text("75")
                        }
                        Button(action: { episodeChunkSize = 100 }) {
                            Text("100")
                        }
                    } label: {
                        Text("\(episodeChunkSize)")
                    }
                }
                Toggle("Fetch Episode metadata", isOn: $fetchEpisodeMetadata)
                    .tint(.accentColor)
            }
            
            Section(header: Text("Modules"), footer: Text("Note that the modules will be replaced only if there is a different version string inside the JSON file.")) {
                Toggle("Refresh Modules on Launch", isOn: $refreshModulesOnLaunch)
                    .tint(.accentColor)
            }
            Section(header: Text("Analytics"), footer: Text("Allow Sora to collect anonymous data to improve the app. No personal information is collected. This can be disabled at any time.\n\n Information collected: \n- App version\n- Device model\n- Module Name/Version\n- Error Messages\n- Title of Watched Content")) {
                Toggle("Enable Analytics", isOn: $analyticsEnabled)
                    .tint(.accentColor)
            }
        }
        .navigationTitle("General")
    }
}
