//
//  SettingsCellButton.swift
//  Sulfur
//
//  Created by Dominic on 22.04.25.
//

import SwiftUI

struct SettingsCellButton: View {
    let setting: Setting

    var body: some View {
        NavigationLink(destination:
            InfoView(title: "Join the Discord", urlString: "https://discord.gg/x7hppDWFDZ")
        ) {
            HStack {
                Text(setting.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
    }
}
