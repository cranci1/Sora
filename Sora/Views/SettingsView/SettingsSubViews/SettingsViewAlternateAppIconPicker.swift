//
//  SettingsViewAlternateAppIconPicker.swift
//  Sulfur
//
//  Created by Dominic on 20.04.25.
//

import SwiftUI

struct SettingsViewAlternateAppIconPicker: View {
    @Binding var isPresented: Bool
    @AppStorage("currentAppIcon") private var currentAppIcon: String?

    // TODO: add alternate app icons
    // TODO: add icons in Assets folder
    // TODO: testing
    let icons: [(name: String, icon: String)] = [
        ("Default", "AppIcon"),
        ("Icon 1", "AppIcon1"),
        ("Icon 2", "AppIcon2"),
        ("Icon 3", "AppIcon3")
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
                            Image(icon.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .padding()
                                .background(
                                    currentAppIcon == icon.name ? Color.accentColor.opacity(0.3) : Color.clear
                                )
                                .cornerRadius(10)

                            Text(icon.name)
                                .font(.caption)
                                .foregroundColor(currentAppIcon == icon.name ? .accentColor : .label)
                        }
                        .onTapGesture {
                            currentAppIcon = icon.name
                            setAppIcon(named: icon.icon)
                            self.isPresented = false
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
            UIApplication.shared.setAlternateIconName(iconName == "AppIcon" ? nil : iconName, completionHandler: { error in
                if let error = error {
                    print("Failed to set alternate icon: \(error.localizedDescription)")
                }
            })
        }
    }
}
