//
//  SettingsViewAlternateAppIconPicker.swift
//  Sulfur
//
//  Created by Dominic on 20.04.25.
//

import SwiftUI

struct SettingsViewAlternateAppIconPicker: View {
    @Binding var isPresented: Bool
    @AppStorage("currentAppIcon") private var currentAppIcon = "Default"

    let icons: [(name: String, icon: String)] = [
        ("Default", "Default"),
        ("Original", "Original"),
        ("Pixel", "Pixel")
    ]

    var body: some View {
        VStack {
            Text("Select an App Icon")
                .font(.headline)
                .padding()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(icons, id: \.name) { icon in
                        VStack {
                            Image("AppIcon_\(icon.icon)_Preview", bundle: .main)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .cornerRadius(10)
                                .shadow(radius: 6)
                                .padding()
                                .background(
                                    currentAppIcon == icon.name ? Color.accentColor.opacity(0.3) : Color.clear
                                )
                                .cornerRadius(10)
                                .accessibilityLabel("Alternative App Icon")
                            Text(icon.name)
                                .font(.caption)
                                .foregroundColor(currentAppIcon == icon.name ? .accentColor : .primary)
                        }
                        .accessibilityAddTraits(.isButton)
                        .onTapGesture {
                            currentAppIcon = icon.name
                            setAppIcon(named: icon.icon)
                        }
                    }
                }
                .padding()
            }
            Spacer()
        }
    }

    private func setAppIcon(named iconName: String) {
        if UIApplication.shared.supportsAlternateIcons {
            UIApplication.shared.setAlternateIconName(iconName == "Default" ? nil : "AppIcon_\(iconName)", completionHandler: { error in
                if let error = error {
                    Logger.shared.log("Failed to set alternate icon: \(error.localizedDescription)", type: "Error")
                    isPresented = false
                }
            })
        }
    }
}
