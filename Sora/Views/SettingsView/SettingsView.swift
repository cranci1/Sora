//
//  SettingsView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Main")) {
                    NavigationLink(destination: SettingsViewGeneral()) {
                        Text("General Preferences")
                    }
                    NavigationLink(destination: SettingsViewPlayer()) {
                        Text("Media Player")
                    }
                    NavigationLink(destination: SettingsViewModule()) {
                        Text("Modules")
                    }
                    NavigationLink(destination: SettingsViewTrackers()) {
                        Text("Trackers")
                    }
                }
                
                Section(header: Text("Info")) {
                    NavigationLink(destination: SettingsViewData()) {
                        Text("Data")
                    }
                    NavigationLink(destination: SettingsViewLogger()) {
                        Text("Logs")
                    }
                }
                
                Section(header: Text("Info")) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/cranci1/Sora") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Sora github repo")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "safari")
                                .foregroundColor(.secondary)
                        }
                    }
                    Button(action: {
                        if let url = URL(string: "https://discord.gg/x7hppDWFDZ") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Join the Discord")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "safari")
                                .foregroundColor(.secondary)
                        }
                    }
                    Button(action: {
                        if let url = URL(string: "https://github.com/cranci1/Sora/issues") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Report an issue")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "safari")
                                .foregroundColor(.secondary)
                        }
                    }
                    Button(action: {
                        if let url = URL(string: "https://github.com/cranci1/Sora/blob/dev/LICENSE") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Licensed under GPLv3.0")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "safari")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Section(footer: Text("Running Sora 0.3.0 - cranci1")) {}
            }
            .navigationTitle("Settings")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .dynamicAccentColor()
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    
    var id: String { self.rawValue }
}

class Settings: ObservableObject {
    @Published var selectedAppearance: Appearance {
        didSet {
            UserDefaults.standard.set(selectedAppearance.rawValue, forKey: "selectedAppearance")
            updateAppearance()
        }
    }
    
    var accentColor: Color {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return .black 
        }
        return window.traitCollection.userInterfaceStyle == .dark ? .white : .black
    }
    
    init() {
        if let appearanceRawValue = UserDefaults.standard.string(forKey: "selectedAppearance"),
           let appearance = Appearance(rawValue: appearanceRawValue) {
            self.selectedAppearance = appearance
        } else {
            self.selectedAppearance = .system
        }
        updateAppearance()
    }
    
    func updateAppearance() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        switch selectedAppearance {
        case .system:
            windowScene.windows.first?.overrideUserInterfaceStyle = .unspecified
        case .light:
            windowScene.windows.first?.overrideUserInterfaceStyle = .light
        case .dark:
            windowScene.windows.first?.overrideUserInterfaceStyle = .dark
        }
        objectWillChange.send()
    }
}

struct DynamicAccentColor: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content.accentColor(colorScheme == .dark ? .white : .black)
    }
}

extension View {
    func dynamicAccentColor() -> some View {
        modifier(DynamicAccentColor())
    }
}
