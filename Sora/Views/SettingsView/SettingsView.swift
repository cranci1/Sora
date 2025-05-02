//
//  SettingsView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var profileStore: ProfileStore
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "BETA"

    var body: some View {
        NavigationView {
            Form {
                Section {
                    NavigationLink(destination: SettingsViewProfile()) {
                        ProfileCell(profile: profileStore.currentProfile)
                    }
                }

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

                Section(header: Text("Diagnostics & Storage")) {
                    NavigationLink(destination: SettingsViewData()) {
                        Text("Data")
                    }
                    NavigationLink(destination: SettingsViewLogger()) {
                        Text("Logs")
                    }
                }

                Section(
                    header: Text("Info"),
                    footer: Text("Running Sora \(version) - cranci1")
                ) {
                    Button(action: {
                        if let url = URL(string: "https://discord.gg/x7hppDWFDZ") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Join the Discord")
                                .foregroundColor(Color(hex: "7289DA"))
                            Spacer()
                            Image(systemName: "safari")
                                .accessibilityLabel("Safari Icon")
                                .foregroundColor(Color(hex: "7289DA"))
                        }
                    }
                    Button(action: {
                        if let url = URL(string: "https://github.com/cranci1/Sora/issues") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Report an issue")
                                .foregroundColor(.red)
                            Spacer()
                            Image(systemName: "safari")
                                .accessibilityLabel("Safari Icon")
                                .foregroundColor(.red)
                        }
                    }
                    Button(action: {
                        if let url = URL(string: "https://github.com/cranci1/Sora") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Github repo")
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "safari")
                                .accessibilityLabel("Safari Icon")
                                .foregroundColor(.secondary)
                        }
                    }
                    Button(action: {
                        if let url = URL(string: "https://github.com/cranci1/Sora/blob/dev/LICENSE") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("License (GPLv3.0)")
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "safari")
                                .accessibilityLabel("Safari Icon")
                                .foregroundColor(.secondary)
                        }
                    }
                    Button(action: {
                        if let url = URL(string: "https://github.com/cranci1/Sora/graphs/contributors") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Contributors")
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "safari")
                                .accessibilityLabel("Safari Icon")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { self.rawValue }
}

class Settings: ObservableObject {
    @Published var shimmerType: ShimmerType {
        didSet {
            UserDefaults.standard.set(shimmerType.rawValue, forKey: "shimmerType")
        }
    }
    @Published var accentColor: Color {
        didSet {
            saveAccentColor(accentColor)
        }
    }

    @Published var selectedAppearance: Appearance {
        didSet {
            UserDefaults.standard.set(selectedAppearance.rawValue, forKey: "selectedAppearance")
            updateAppearance()
        }
    }

    init() {
        if let shimmerRawValue = UserDefaults.standard.string(forKey: "shimmerType"),
           let shimmer = ShimmerType(rawValue: shimmerRawValue) {
            self.shimmerType = shimmer
        } else {
            self.shimmerType = .shimmer
        }

        if let colorData = UserDefaults.standard.data(forKey: "accentColor"),
           let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
            self.accentColor = Color(uiColor)
        } else {
            self.accentColor = .accentColor
        }

        if let appearanceRawValue = UserDefaults.standard.string(forKey: "selectedAppearance"),
           let appearance = Appearance(rawValue: appearanceRawValue) {
            self.selectedAppearance = appearance
        } else {
            self.selectedAppearance = .system
        }

        applyColorToUIKit(accentColor)
        updateAppearance()
    }

    private func applyColorToUIKit(_ color: Color) {
        let newColor = UIColor(color)
        let tempStepper = UIStepper()
        tempStepper.tintColor = newColor
        UIStepper.appearance().setDecrementImage(tempStepper.decrementImage(for: .normal), for: .normal)
        UIStepper.appearance().setIncrementImage(tempStepper.incrementImage(for: .normal), for: .normal)
        UIRefreshControl.appearance().tintColor = newColor
    }

    private func saveAccentColor(_ color: Color) {
        let uiColor = UIColor(color)
        do {
            let colorData = try NSKeyedArchiver.archivedData(withRootObject: uiColor, requiringSecureCoding: false)
            UserDefaults.standard.set(colorData, forKey: "accentColor")
        } catch {
            Logger.shared.log("Failed to save accent color: \(error.localizedDescription)")
        }
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
    }
}
