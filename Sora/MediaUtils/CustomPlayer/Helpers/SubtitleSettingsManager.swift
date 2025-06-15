//
//  SubtitleSettingsManager.swift
//  Sulfur
//
//  Created by Francesco on 09/03/25.
//

import UIKit

struct SubtitleSettings: Codable {
    var enabled: Bool = true
    var foregroundColor: String = "white"
    var fontSize: Double = 20.0
    var shadowRadius: Double = 1.0
    var backgroundEnabled: Bool = true
    var bottomPadding: CGFloat = 20.0
    var subtitleDelay: Double = 0.0
}

class SubtitleSettingsManager {
    static let shared = SubtitleSettingsManager()
    
    private let userDefaultsKey = "SubtitleSettings"
    
    var settings: SubtitleSettings {
        get {
            if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
               let savedSettings = try? JSONDecoder().decode(SubtitleSettings.self, from: data) {
                return savedSettings
            }
            return SubtitleSettings()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: userDefaultsKey)
            }
        }
    }
    
    func update(_ updateBlock: (inout SubtitleSettings) -> Void) {
        var currentSettings = settings
        updateBlock(&currentSettings)
        settings = currentSettings
    }
}
