//
//  SettingsView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                Form {
                    // Main Section
                    Section(header: Text("Main")) {
                        CustomNavigationLink(destination: SettingsViewGeneral(), title: "General Preferences", iconName: "gear")
                        CustomNavigationLink(destination: SettingsViewPlayer(), title: "Media Player", iconName: "play.circle")
                        CustomNavigationLink(destination: SettingsViewModule(), title: "Modules", iconName: "puzzlepiece")
                        CustomNavigationLink(destination: SettingsViewTrackers(), title: "Trackers", iconName: "eye")
                    }
                    
                    // Info Section
                    Section(header: Text("Info")) {
                        CustomNavigationLink(destination: SettingsViewData(), title: "Data", iconName: "folder")
                        CustomNavigationLink(destination: SettingsViewLogger(), title: "Logs", iconName: "doc.text")
                    }
                    
                    // Links Section
                    Section(header: Text("Links")) {
                        CustomButton(urlString: "https://github.com/cranci1/Sora", title: "Sora github repo", iconName: "link")
                        CustomButton(urlString: "https://discord.gg/x7hppDWFDZ", title: "Join the Discord", iconName: "bubble.left.and.bubble.right.fill") // Discord community icon
                        CustomButton(urlString: "https://github.com/cranci1/Sora/issues", title: "Report an issue", iconName: "exclamationmark.circle")
                        CustomButton(urlString: "https://github.com/cranci1/Sora/blob/dev/LICENSE", title: "License (GPLv3.0)", iconName: "book")
                    }
                    
                    Section(footer: Text("Running Sora 0.2.2 - cranci1")) {}
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
                .padding(.bottom, 10)
                .frame(minHeight: 600)
            }
            .navigationTitle("Settings")
            .edgesIgnoringSafeArea(.bottom)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct CustomNavigationLink<Destination: View>: View {
    let destination: Destination
    let title: String
    let iconName: String

    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.primary)
                    .frame(width: 20, height: 20)
                Text(title)
                    .padding(.vertical, 6)
                    .foregroundColor(.primary)
                    .font(.subheadline)
            }
            .padding(.vertical, 6)
            .background(Color.clear)
        }
    }
}

struct CustomButton: View {
    let urlString: String
    let title: String
    let iconName: String

    var body: some View {
        Button(action: {
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.primary)
                    .frame(width: 20, height: 20)
                Text(title)
                    .foregroundColor(.primary)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "safari")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .foregroundColor(.primary)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 2)
        .background(Color.clear)
    }
}



enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    
    var id: String { self.rawValue }
}

class Settings: ObservableObject {
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
        updateAppearance()
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
