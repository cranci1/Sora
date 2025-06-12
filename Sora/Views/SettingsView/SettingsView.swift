//
//  SettingsView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import NukeUI

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

fileprivate struct ModulePreviewRow: View {
    @EnvironmentObject var moduleManager: ModuleManager
    @AppStorage("selectedModuleId") private var selectedModuleId: String?
    
    private var selectedModule: ScrapingModule? {
        guard let id = selectedModuleId else { return nil }
        return moduleManager.modules.first { $0.id.uuidString == id }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            if let module = selectedModule {
                LazyImage(url: URL(string: module.metadata.iconUrl)) { state in
                    if let uiImage = state.imageContainer?.image {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "cube")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(module.metadata.sourceName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("Tap to manage your modules")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Image(systemName: "cube")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("No Module Selected")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("Tap to select a module")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
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
    }
}

struct SettingsView: View {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "ALPHA"
    @Environment(\.colorScheme) var colorScheme
    @StateObject var settings = Settings()
    @EnvironmentObject var moduleManager: ModuleManager
    
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
                    
                    // Modules Section at the top
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MODULES")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 20)
                        
                        NavigationLink(destination: SettingsViewModule()) {
                            ModulePreviewRow()
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MAIN SETTINGS")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            NavigationLink(destination: SettingsViewGeneral()) {
                                SettingsNavigationRow(icon: "gearshape", title: "General Settings")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewPlayer()) {
                                SettingsNavigationRow(icon: "play.circle", title: "Player Settings")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewDownloads()) {
                                SettingsNavigationRow(icon: "arrow.down.circle", title: "Download Settings")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewTrackers()) {
                                SettingsNavigationRow(icon: "square.stack.3d.up", title: "Tracking Services")
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
                        Text("DATA & LOGS")
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
                        Text("INFORMATION")
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
                                    title: "Join Discord Community",
                                    isExternal: true,
                                    textColor: .gray
                                )
                            }
                            Divider().padding(.horizontal, 16)

                            Link(destination: URL(string: "https://github.com/cranci1/Sora/issues")!) {
                                SettingsNavigationRow(
                                    icon: "exclamationmark.circle",
                                    title: "Report an Issue on GitHub",
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

                    Text("Sora \(version) by cranci1")
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
