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
                                SettingsRow(icon: "gearshape", title: "General Preferences")
                            }
                            
                            Divider()
                                .padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewPlayer()) {
                                SettingsRow(icon: "play.circle", title: "Video Player")
                            }
                            
                            Divider()
                                .padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewModule()) {
                                SettingsRow(icon: "cube", title: "Modules")
                            }
                            
                            Divider()
                                .padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewTrackers()) {
                                SettingsRow(icon: "square.stack.3d.up", title: "Trackers")
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
                                SettingsRow(icon: "folder", title: "Data")
                            }
                            
                            Divider()
                                .padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewLogger()) {
                                SettingsRow(icon: "doc.text", title: "Logs")
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
                            Link(destination: URL(string: "https://github.com/cranci1/Sora")!) {
                                SettingsRow(icon: "chevron.left.forwardslash.chevron.right", title: "Sora GitHub Repository", isExternal: true, textColor: .gray)
                            }
                            
                            Divider()
                                .padding(.horizontal, 16)
                            
                            Link(destination: URL(string: "https://discord.gg/x7hppDWFDZ")!) {
                                SettingsRow(icon: "bubble.left.and.bubble.right", title: "Join the Discord", isExternal: true, textColor: .gray)
                            }
                            
                            Divider()
                                .padding(.horizontal, 16)
                            
                            Link(destination: URL(string: "https://github.com/cranci1/Sora/issues")!) {
                                SettingsRow(icon: "exclamationmark.circle", title: "Report an Issue", isExternal: true, textColor: .gray)
                            }
                            
                            Divider()
                                .padding(.horizontal, 16)
                            
                            Link(destination: URL(string: "https://github.com/cranci1/Sora/blob/dev/LICENSE")!) {
                                SettingsRow(icon: "doc.text", title: "License (GPLv3.0)", isExternal: true, textColor: .gray)
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
                    
                    Text("Running Sora 0.3.0 - cranci1")
                        .font(.footnote)
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .scrollViewBottomPadding()
                .padding(.bottom, 20)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .dynamicAccentColor()
        .navigationBarHidden(true)
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var isExternal: Bool = false
    var textColor: Color = .primary
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundStyle(textColor)
            
            Text(title)
                .foregroundStyle(textColor)
            
            Spacer()
            
            Image(systemName: isExternal ? "arrow.up.forward" : "chevron.right")
                .foregroundStyle(.gray)
                .font(.footnote)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
