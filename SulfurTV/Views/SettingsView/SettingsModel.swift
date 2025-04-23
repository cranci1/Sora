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

extension LocalizedStringKey {
    var stringKey: String? {
        Mirror(reflecting: self).children.first(where: { $0.label == "key" })?.value as? String
    }
}

struct Setting: Identifiable, Hashable {
    let id: Int
    let title: LocalizedStringKey
    let destination: SettingDestination

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title.stringKey)
        hasher.combine(destination)
    }

    static func ==(lhs: Setting, rhs: Setting) -> Bool {
        return lhs.id == rhs.id && lhs.title.stringKey == rhs.title.stringKey && lhs.destination == rhs.destination
    }
}
