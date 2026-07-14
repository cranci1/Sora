//
//  ModuleSettings.swift
//  Sulfur
//
//  Created by Francesco on 14/07/26.
//

import Foundation

struct ModuleSetting: Identifiable, Hashable {
    enum SettingType: String, Codable {
        case string, bool, int, float
        
        init(rawType: String) {
            switch rawType.lowercased() {
            case "bool", "boolean":
                self = .bool
            case "int", "integer":
                self = .int
            case "float", "double", "number":
                self = .float
            default:
                self = .string
            }
        }
    }
    
    var id: String { key }
    let key: String
    var value: String
    let type: SettingType
    let comment: String?
    let options: [String]?
    
    init(key: String, value: String, type: SettingType, comment: String? = nil, options: [String]? = nil) {
        self.key = key
        self.value = value
        self.type = type
        self.comment = comment
        self.options = options
    }
}

private struct ModuleSettingSchemaEntry: Codable {
    let key: String
    let type: String
    let comment: String?
    let defaultValue: String?
    let options: [String]?
    
    enum CodingKeys: String, CodingKey {
        case key, type, comment, options
        case defaultValue = "default"
    }
}

extension ModuleManager {
    func hasSettings(_ module: ScrapingModule) -> Bool {
        guard let content = try? getModuleContent(module) else { return false }
        return !Self.parseSettingsSchema(from: content).isEmpty
    }
    
    func getModuleSettings(_ module: ScrapingModule) -> [ModuleSetting] {
        guard let content = try? getModuleContent(module) else { return [] }
        let schema = Self.parseSettingsSchema(from: content)
        let overrides = loadSettingOverrides(for: module)
        
        return schema.map { entry in
            let type = ModuleSetting.SettingType(rawValue: entry.type.lowercased()) ?? .string
            let storedValue = overrides[entry.key] ?? entry.defaultValue ?? ""
            return ModuleSetting(
                key: entry.key,
                value: storedValue,
                type: type,
                comment: entry.comment,
                options: entry.options
            )
        }
    }
    
    @discardableResult
    func updateModuleSettings(_ module: ScrapingModule, settings: [ModuleSetting]) -> Bool {
        var overrides: [String: String] = [:]
        for setting in settings {
            overrides[setting.key] = setting.value
        }
        
        guard let data = try? JSONEncoder().encode(overrides) else {
            Logger.shared.log("Failed to encode settings for module: \(module.metadata.sourceName)", type: "Error")
            return false
        }
        
        UserDefaults.standard.set(data, forKey: settingsStorageKey(for: module))
        Logger.shared.log("Updated settings for module: \(module.metadata.sourceName)")
        return true
    }
    
    private func settingsStorageKey(for module: ScrapingModule) -> String {
        "moduleSettings_\(module.id.uuidString)"
    }
    
    private func loadSettingOverrides(for module: ScrapingModule) -> [String: String] {
        guard
            let data = UserDefaults.standard.data(forKey: settingsStorageKey(for: module)),
            let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }
    
    fileprivate static func parseSettingsSchema(from script: String) -> [ModuleSettingSchemaEntry] {
        guard
            let markerRange = script.range(of: "SETTINGS_SCHEMA:"),
            let lineEnd = script[markerRange.upperBound...].firstIndex(of: "\n")
        else { return [] }
        
        let jsonString = String(script[markerRange.upperBound..<lineEnd]).trimmingCharacters(in: .whitespaces)
        guard let data = jsonString.data(using: .utf8) else { return [] }
        
        do {
            return try JSONDecoder().decode([ModuleSettingSchemaEntry].self, from: data)
        } catch {
            Logger.shared.log("Failed to parse SETTINGS_SCHEMA: \(error.localizedDescription)", type: "Error")
            return []
        }
    }
}
