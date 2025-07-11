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
    let titleKey: String
    let isExternal: Bool
    let textColor: Color
    
    init(icon: String, titleKey: String, isExternal: Bool = false, textColor: Color = .primary) {
        self.icon = icon
        self.titleKey = titleKey
        self.isExternal = isExternal
        self.textColor = textColor
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundStyle(textColor)
            
            Text(NSLocalizedString(titleKey, comment: ""))
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
    @Environment(\.colorScheme) var colorScheme
    @StateObject var settings = Settings()
    @EnvironmentObject var moduleManager: ModuleManager
    
    @State private var isNavigationActive = false
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MODULES")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 20)
                        
                        NavigationLink(destination: SettingsViewModule().navigationBarBackButtonHidden(false)) {
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
                            NavigationLink(destination: SettingsViewGeneral().navigationBarBackButtonHidden(false)) {
                                SettingsNavigationRow(icon: "gearshape", titleKey: "General Preferences")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewPlayer().navigationBarBackButtonHidden(false)) {
                                SettingsNavigationRow(icon: "play.circle", titleKey: "Video Player")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewDownloads().navigationBarBackButtonHidden(false)) {
                                SettingsNavigationRow(icon: "arrow.down.circle", titleKey: "Downloads")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewTrackers().navigationBarBackButtonHidden(false)) {
                                SettingsNavigationRow(icon: "square.3.stack.3d", titleKey: "Trackers")
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
                            NavigationLink(destination: SettingsViewData().navigationBarBackButtonHidden(false)) {
                                SettingsNavigationRow(icon: "folder", titleKey: "Data")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewLogger().navigationBarBackButtonHidden(false)) {
                                SettingsNavigationRow(icon: "doc.text", titleKey: "Logs")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewBackup().navigationBarBackButtonHidden(false)) {
                                SettingsNavigationRow(icon: "arrow.triangle.2.circlepath", titleKey: NSLocalizedString("Backup & Restore", comment: "Settings navigation row for backup and restore"))
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
                        Text(NSLocalizedString("INFOS", comment: ""))
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            NavigationLink(destination: SettingsViewAbout().navigationBarBackButtonHidden(false)) {
                                SettingsNavigationRow(icon: "info.circle", titleKey: "About Sora")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            Link(destination: URL(string: "https://github.com/cranci1/Sora")!) {
                                HStack {
                                    Image("Github Icon")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .padding(.leading, 2)
                                        .padding(.trailing, 4)
                                    
                                    Text(NSLocalizedString("Sora GitHub Repository", comment: ""))
                                        .foregroundStyle(.gray)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "safari")
                                        .foregroundStyle(.gray)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            Divider().padding(.horizontal, 16)
                            
                            Link(destination: URL(string: "https://discord.gg/x7hppDWFDZ")!) {
                                HStack {
                                    Image("Discord Icon")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .padding(.leading, 2)
                                        .padding(.trailing, 4)
                                    
                                    Text(NSLocalizedString("Join the Discord", comment: ""))
                                        .foregroundStyle(.gray)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "safari")
                                        .foregroundStyle(.gray)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            Divider().padding(.horizontal, 16)
                            
                            Link(destination: URL(string: "https://github.com/cranci1/Sora/issues")!) {
                                SettingsNavigationRow(
                                    icon: "exclamationmark.circle.fill",
                                    titleKey: "Report an Issue",
                                    isExternal: true,
                                    textColor: .gray
                                )
                            }
                            Divider().padding(.horizontal, 16)
                            
                            Link(destination: URL(string: "https://github.com/cranci1/Sora/blob/dev/LICENSE")!) {
                                SettingsNavigationRow(
                                    icon: "doc.text.fill",
                                    titleKey: "License (GPLv3.0)",
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
                    
                    Text("Sora 1.0.1 by cranci1")
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
    @Published var selectedLanguage: String {
        didSet {
            UserDefaults.standard.set(selectedLanguage, forKey: "selectedLanguage")
            updateLanguage()
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
        self.selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "English"
        updateAppearance()
        updateLanguage()
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
    
    func updateLanguage() {
        let languageCode: String
        switch selectedLanguage {
        case "Dutch":
            languageCode = "nl"
        case "French":
            languageCode = "fr"
        case "German":
            languageCode = "de"
        case "Arabic":
            languageCode = "ar"
        case "Bosnian":
            languageCode = "bos"
        case "Czech":
            languageCode = "cs"
        case "Slovak":
            languageCode = "sk"
        case "Spanish":
            languageCode = "es"
        case "Russian":
            languageCode = "ru"
        case "Norsk":
            languageCode = "nn"
        case "Kazakh":
            languageCode = "kk"
        case "Mongolian":
            languageCode = "mn"
        case "Swedish":
            languageCode = "sv"
        case "Italian":
            languageCode = "it"
        default:
            languageCode = "en"
        }
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
}
