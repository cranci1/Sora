//
//  SettingsViewPlayer.swift
//  Sora
//
//  Created by Francesco on 31/01/25.
//

import SwiftUI

struct SettingsViewPlayer: View {
    @AppStorage("externalPlayer") private var externalPlayer: String = "Sora"
    @AppStorage("alwaysLandscape") private var isAlwaysLandscape = false
    @AppStorage("hideNextButton") private var isHideNextButton = false
    @AppStorage("rememberPlaySpeed") private var isRememberPlaySpeed = false
    @AppStorage("holdSpeedPlayer") private var holdSpeedPlayer: Double = 2.0
    
    private let mediaPlayers = ["Default", "VLC", "OutPlayer", "Infuse", "nPlayer", "Sora"]
    
    var body: some View {
        Form {
            Section(header: Text("Media Player"), footer: Text("Some features are limited to the Sora and Default player, such as ForceLandscape and holdSpeed")) {
                HStack {
                    Text("Media Player")
                    Spacer()
                    Menu(externalPlayer) {
                        ForEach(mediaPlayers, id: \.self) { player in
                            Button(action: {
                                externalPlayer = player
                            }) {
                                Text(player)
                            }
                        }
                    }
                }
                
                Toggle("Hide 'Watch Next' after 5s", isOn: $isHideNextButton)
                    .tint(.accentColor)
                
                Toggle("Force Landscape", isOn: $isAlwaysLandscape)
                    .tint(.accentColor)
            }
            
            Section(header: Text("Speed Settings")) {
                Toggle("Remember Playback speed", isOn: $isRememberPlaySpeed)
                    .tint(.accentColor)
                
                HStack {
                    Text("Hold Speed:")
                    Spacer()
                    Stepper(
                        value: $holdSpeedPlayer,
                        in: 0.25...2.0,
                        step: 0.25
                    ) {
                        Text(String(format: "%.2f", holdSpeedPlayer))
                    }
                }
            }
            
            SubtitleSettingsSection()
        }
        .navigationTitle("Player")
    }
}

struct SubtitleSettingsSection: View {
    @State private var foregroundColor: String = SubtitleSettingsManager.shared.settings.foregroundColor
    @State private var fontSize: Double = SubtitleSettingsManager.shared.settings.fontSize
    @State private var shadowRadius: Double = SubtitleSettingsManager.shared.settings.shadowRadius
    @State private var backgroundEnabled: Bool = SubtitleSettingsManager.shared.settings.backgroundEnabled
    @State private var bottomPadding: CGFloat = SubtitleSettingsManager.shared.settings.bottomPadding

    private let colors = ["white", "yellow", "green", "blue", "red", "purple"]
    private let shadowOptions = [0, 1, 3, 6]

    var body: some View {
        Section(header: Text("Subtitle Settings")) {
            HStack {
                Text("Subtitle Color")
                Spacer()
                Menu(foregroundColor) {
                    ForEach(colors, id: \.self) { color in
                        Button(action: {
                            foregroundColor = color
                            SubtitleSettingsManager.shared.update { settings in
                                settings.foregroundColor = color
                            }
                        }) {
                            Text(color.capitalized)
                        }
                    }
                }
            }
            
            HStack {
                Text("Shadow")
                Spacer()
                Menu("\(Int(shadowRadius))") {
                    ForEach(shadowOptions, id: \.self) { option in
                        Button(action: {
                            shadowRadius = Double(option)
                            SubtitleSettingsManager.shared.update { settings in
                                settings.shadowRadius = Double(option)
                            }
                        }) {
                            Text("\(option)")
                        }
                    }
                }
            }
            
            Toggle("Background Enabled", isOn: $backgroundEnabled)
                .tint(.accentColor)
                .onChange(of: backgroundEnabled) { newValue in
                    SubtitleSettingsManager.shared.update { settings in
                        settings.backgroundEnabled = newValue
                    }
                }
            
            HStack {
                Text("Font Size:")
                Spacer()
                Stepper("\(Int(fontSize))", value: $fontSize, in: 12...36, step: 1)
                    .onChange(of: fontSize) { newValue in
                        SubtitleSettingsManager.shared.update { settings in
                            settings.fontSize = newValue
                        }
                    }
            }
            
            HStack {
                Text("Bottom Padding:")
                Spacer()
                Stepper("\(Int(bottomPadding))", value: $bottomPadding, in: 0...50, step: 1)
                    .onChange(of: bottomPadding) { newValue in
                        SubtitleSettingsManager.shared.update { settings in
                            settings.bottomPadding = newValue
                        }
                    }
            }
        }
    }
}
