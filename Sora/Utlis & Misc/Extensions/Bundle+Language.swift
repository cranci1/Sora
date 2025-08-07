//
//  Bundle+Language.swift
//  Sora
//
//  Created by paul on 2025-07-24.
//

import Foundation

class LanguageBundleManager {
    static let shared = LanguageBundleManager()
    
    private var bundles: [String: Bundle] = [:]
    
    func localizedBundle(for language: String) -> Bundle {
        if let cachedBundle = bundles[language] {
            return cachedBundle
        }
        
        let mainBundle = Bundle.main
        if let path = mainBundle.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            bundles[language] = bundle
            return bundle
        }
        
        if language == "mn-Cyrl" {
            if let path = mainBundle.path(forResource: "mn", ofType: "lproj"),
               let bundle = Bundle(path: path) {
                bundles[language] = bundle
                Logger.shared.log("Found Mongolian bundle using mn.lproj", type: "Debug")
                return bundle
            }
        }

        if language == "ro" {
            if let path = mainBundle.path(forResource: "ro", ofType: "lproj"),
               let bundle = Bundle(path: path) {
                bundles[language] = bundle
                Logger.shared.log("Found Romanian bundle using ro.lproj", type: "Debug")
                return bundle
            } else {
                Logger.shared.log("Could not find bundle for Romanian (ro)", type: "Error")
            }
        }
        
        Logger.shared.log("Could not find bundle for language: \(language)", type: "Error")
        return mainBundle
    }
}

extension String {
    func localized(language: String) -> String {
        let bundle = LanguageBundleManager.shared.localizedBundle(for: language)
        return bundle.localizedString(forKey: self, value: nil, table: nil)
    }
    
    static var currentLanguageCode: String {
        if let languages = UserDefaults.standard.object(forKey: "AppleLanguages") as? [String], 
           let primaryLanguage = languages.first {
            return primaryLanguage
        }
        return "en"
    }
}

extension Bundle {
    static var currentLanguageBundle: Bundle {
        return LanguageBundleManager.shared.localizedBundle(for: String.currentLanguageCode)
    }
} 