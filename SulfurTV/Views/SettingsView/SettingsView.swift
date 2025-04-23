//
//  ExploreView.swift
//  Sulfur
//
//  Created by Dominic on 22.04.25.
//

import SwiftUI

struct SettingsView: View {
    @FocusState private var focusedSetting: Int?
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "BETA"

    private let settings: [Setting] = [
        Setting(id: 1, title: LocalizedStringKey("General Preferences"), destination: .general),
        Setting(id: 2, title: LocalizedStringKey("Media Player"), destination: .media),
        Setting(id: 3, title: LocalizedStringKey("Modules"), destination: .modules),
        Setting(id: 4, title: LocalizedStringKey("Trackers"), destination: .trackers),
        Setting(id: 5, title: LocalizedStringKey("Data"), destination: .data),
        Setting(id: 6, title: LocalizedStringKey("Logs"), destination: .logs),
        Setting(id: 7, title: LocalizedStringKey("Info"), destination: .info)
    ]

    var body: some View {
        NavigationView {
            HStack(spacing: 0) {

                // Logo block
                VStack {
                    Button(action: { }, label: {
                        Image("Logo")
                            .resizable()
                            .padding(80)
                            .background(
                                Image("Background")
                                    .resizable()
                                    .scaledToFill()
                            )
                    })
                    .aspectRatio(1.0, contentMode: .fill)
                    .buttonStyle(.card)
                    .focused($focusedSetting, equals: 0)
                    .cornerRadius(100)
                    .shadow(radius: 30)
                    .padding(.horizontal, 100)

                    Text("Running Sora \(version)\nby cranci1")
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding()
                }
                    .padding(100)
                    .frame(maxWidth: .infinity)

                // Settings list
                VStack {
                    ForEach(settings) { setting in
                        SettingsCellButton(setting: setting)
                            .focused($focusedSetting, equals: setting.id)
                    }
                }
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
