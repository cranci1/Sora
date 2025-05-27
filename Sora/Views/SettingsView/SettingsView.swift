//
//  SettingsView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI

struct SettingsView: View {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "ALPHA"
    
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
                    
                    // MAIN SECTION
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MAIN")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            NavigationLink(destination: SettingsViewGeneral()) {
                                SettingsRow(icon: "gearshape", title: "General Preferences")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewPlayer()) {
                                SettingsRow(icon: "play.circle", title: "Video Player")
                            }
                            Divider().padding(.horizontal, 16)
                            
                            NavigationLink(destination: SettingsViewModule()) {
                                SettingsRow(icon: "cube", title: "Modules")
                            }
                            Divider().padding(.horizontal, 16)
                            
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
                    
                    // DATA/LOGS SECTION
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DATA/LOGS")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            NavigationLink(destination: SettingsViewData()) {
                                SettingsRow(icon: "folder", title: "Data")
                            }
                            Divider().padding(.horizontal, 16)
                            
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
                    
                    // INFOS SECTION
                    VStack(alignment: .leading, spacing: 4) {
                        Text("INFOS")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            NavigationLink(destination: SettingsViewAbout()) {
                                SettingsRow(icon: "info.circle", title: "About Sora")
                            }
                            Divider().padding(.horizontal, 16)

                            Link(destination: URL(string: "https://github.com/cranci1/Sora")!) {
                                SettingsRow(icon: "chevron.left.forwardslash.chevron.right", title: "Sora GitHub Repository", isExternal: true, textColor: .gray)
                            }
                            Divider().padding(.horizontal, 16)

                            Link(destination: URL(string: "https://discord.gg/x7hppDWFDZ")!) {
                                SettingsRow(icon: "bubble.left.and.bubble.right", title: "Join the Discord", isExternal: true, textColor: .gray)
                            }
                            Divider().padding(.horizontal, 16)

                            Link(destination: URL(string: "https://github.com/cranci1/Sora/issues")!) {
                                SettingsRow(icon: "exclamationmark.circle", title: "Report an Issue", isExternal: true, textColor: .gray)
                            }
                            Divider().padding(.horizontal, 16)

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

                    Text("Running Sora \(version) - cranci1")
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
