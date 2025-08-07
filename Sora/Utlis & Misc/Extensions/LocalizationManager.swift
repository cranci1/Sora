//
//  LocalizationManager.swift
//  Sora
//
//  Created by paul on 2025-07-24.
//

import Foundation
import SwiftUI

class LocalizationManager {
    static let shared = LocalizationManager()
    
    private var currentLanguage: String = "en"
    private var translationCache: [String: [String: String]] = [:]
    
    private init() {
        if let languages = UserDefaults.standard.object(forKey: "AppleLanguages") as? [String],
           let primaryLanguage = languages.first {
            currentLanguage = primaryLanguage
            Logger.shared.log("LocalizationManager initialized with language: \(primaryLanguage)", type: "Debug")
        }
        
        loadTranslationsIfNeeded(for: "mn")
        loadTranslationsIfNeeded(for: "ro")
    }
    
    func setLanguage(_ languageCode: String) {
        currentLanguage = languageCode
        loadTranslationsIfNeeded(for: languageCode)
        Logger.shared.log("LocalizationManager language set to: \(languageCode)", type: "Debug")
    }
    
    func localizedString(for key: String, comment: String = "") -> String {
        if currentLanguage == "mn" || currentLanguage == "mn-Cyrl" {
            if let translations = translationCache["mn"],
               let localizedString = translations[key] {
                return localizedString
            }
            
            loadTranslationsIfNeeded(for: "mn")
            
            if let translations = translationCache["mn"],
               let localizedString = translations[key] {
                return localizedString
            }
            
            Logger.shared.log("Missing Mongolian translation for key: \(key)", type: "Debug")
        }

        if currentLanguage == "ro" {
            if let translations = translationCache["ro"],
               let localizedString = translations[key] {
                return localizedString
            }

            loadTranslationsIfNeeded(for: "ro")

            if let translations = translationCache["ro"],
               let localizedString = translations[key] {
                return localizedString
            }

            Logger.shared.log("Missing Romanian translation for key: \(key)", type: "Debug")
        }
        
        return NSLocalizedString(key, comment: comment)
    }
    
    private func loadTranslationsIfNeeded(for languageCode: String) {
        if translationCache[languageCode] != nil {  
            return
        }
        
        guard let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "\(languageCode).lproj") else {
            Logger.shared.log("Could not find Localizable.strings for \(languageCode)", type: "Error")
            return
        }
        
        do {
            let fileContents = try String(contentsOfFile: path, encoding: .utf8)
            var translations: [String: String] = [:]
            
            let lines = fileContents.components(separatedBy: .newlines)
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if trimmedLine.isEmpty || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("//") {
                    continue
                }

                if let range = trimmedLine.range(of: "\" = \"") {
                    let keyStartIndex = trimmedLine.index(after: trimmedLine.startIndex)
                    let keyEndIndex = range.lowerBound
                    let valueStartIndex = range.upperBound
                    let valueEndIndex = trimmedLine.index(trimmedLine.endIndex, offsetBy: -2, limitedBy: trimmedLine.startIndex) ?? trimmedLine.startIndex
                    
                    if keyStartIndex < keyEndIndex && valueStartIndex < valueEndIndex {
                        let key = String(trimmedLine[keyStartIndex..<keyEndIndex])
                        let value = String(trimmedLine[valueStartIndex..<valueEndIndex])
                        translations[key] = value
                    }
                }
            }
            
            translationCache[languageCode] = translations
            Logger.shared.log("Loaded \(translations.count) translations for \(languageCode)", type: "Debug")
        } catch {
            Logger.shared.log("Error loading translations for \(languageCode): \(error.localizedDescription)", type: "Error")
        }
    }
}

extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(for: self)
    }
}

extension Text {
    init(localized key: String) {
        self.init(verbatim: LocalizationManager.shared.localizedString(for: key))
    }
} 