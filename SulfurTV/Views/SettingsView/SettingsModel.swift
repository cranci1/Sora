//
//  SettingsModel.swift
//  Sulfur
//
//  Created by Dominic on 22.04.25.
//

import SwiftUI

enum SettingDestination: Hashable {
    case general, media, modules, trackers, data, logs, info
}

struct Setting: Identifiable, Hashable {
    let id: Int
    let title: String
    let destination: SettingDestination
}
