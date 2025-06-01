//
//  SettingsView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI

fileprivate struct SettingsNavigationRow: View {
    let icon: String
    let title: String
    let isExternal: Bool
    let textColor: Color
    
    init(icon: String, title: String, isExternal: Bool = false, textColor: Color = .primary) {
        self.icon = icon
        self.title = title
        self.isExternal = isExternal
        self.textColor = textColor
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundStyle(textColor)
            
            Text(title)
                .foregroundStyle(textColor)
            
            Spacer()
            
            if isExternal {
                Image(systemName: "safari")
                    .foregroundStyle(.gray)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
struct SettingsView: View {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "ALPHA"
    @Environment(\.colorScheme) var colorScheme
    @StateObject var settings = Settings()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MAIN")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            NavigationLink(destination: SettingsViewGeneral()) {
                                SettingsNavigationRow(icon: "gearshape", title: "General Preferences")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewPlayer()) {
                                SettingsNavigationRow(icon: "play.circle", title: "Video Player")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewDownloads()) {
                                SettingsNavigationRow(icon: "arrow.down.circle", title: "Download")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewModule()) {
                                SettingsNavigationRow(icon: "cube", title: "Modules")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewTrackers()) {
                                SettingsNavigationRow(icon: "square.stack.3d.up", title: "Trackers")
                            }
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
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DATA/LOGS")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            NavigationLink(destination: SettingsViewData()) {
                                SettingsNavigationRow(icon: "folder", title: "Data")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewLogger()) {
                                SettingsNavigationRow(icon: "doc.text", title: "Logs")
                            }
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
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("INFOS")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            NavigationLink(destination: SettingsViewAbout()) {
                                SettingsNavigationRow(icon: "info.circle", title: "About Sora")
                            }
                            Divider().padding(.horizontal, 16)

                            Link(destination: URL(string: "https://github.com/cranci1/Sora")!) {
                                SettingsNavigationRow(
                                    icon: "chevron.left.forwardslash.chevron.right",
                                    title: "Sora GitHub Repository",
                                    isExternal: true,
                                    textColor: .gray
                                )
                            }
                            Divider().padding(.horizontal, 16)

                            Link(destination: URL(string: "https://discord.gg/x7hppDWFDZ")!) {
                                SettingsNavigationRow(
                                    icon: "bubble.left.and.bubble.right",
                                    title: "Join the Discord",
                                    isExternal: true,
                                    textColor: .gray
                                )
                            }
                            Divider().padding(.horizontal, 16)

                            Link(destination: URL(string: "https://github.com/cranci1/Sora/issues")!) {
                                SettingsNavigationRow(
                                    icon: "exclamationmark.circle",
                                    title: "Report an Issue",
                                    isExternal: true,
                                    textColor: .gray
                                )
                            }
                            Divider().padding(.horizontal, 16)

                            Link(destination: URL(string: "https://github.com/cranci1/Sora/blob/dev/LICENSE")!) {
                                SettingsNavigationRow(
                                    icon: "doc.text",
                                    title: "License (GPLv3.0)",
                                    isExternal: true,
                                    textColor: .gray
                                )
                            }
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
                    }

                    Text("Running Sora \(version) - cranci1")
                        .font(.footnote)
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .scrollViewBottomPadding()
                .padding(.bottom, 20)
            }
            .deviceScaled()
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarHidden(true)
        .onChange(of: colorScheme) { newScheme in
            if settings.selectedAppearance == .system {
                settings.updateAccentColor(currentColorScheme: newScheme)
            }
        }
        .onChange(of: settings.selectedAppearance) { _ in
            settings.updateAccentColor(currentColorScheme: colorScheme)
        }
        .onAppear {
            settings.updateAccentColor(currentColorScheme: colorScheme)
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    
    var id: String { self.rawValue }
}

class Settings: ObservableObject {
    @Published var accentColor: Color {
        didSet {
        }
    }
    @Published var selectedAppearance: Appearance {
        didSet {
            UserDefaults.standard.set(selectedAppearance.rawValue, forKey: "selectedAppearance")
            updateAppearance()
        }
    }
    
    init() {
        self.accentColor = .primary
        if let appearanceRawValue = UserDefaults.standard.string(forKey: "selectedAppearance"),
           let appearance = Appearance(rawValue: appearanceRawValue) {
            self.selectedAppearance = appearance
        } else {
            self.selectedAppearance = .system
        }
        updateAppearance()
    }
    
    func updateAccentColor(currentColorScheme: ColorScheme? = nil) {
        switch selectedAppearance {
        case .system:
            if let scheme = currentColorScheme {
                accentColor = scheme == .dark ? .white : .black
            } else {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first else { return }
                accentColor = window.traitCollection.userInterfaceStyle == .dark ? .white : .black
            }
        case .light:
            accentColor = .black
        case .dark:
            accentColor = .white
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
