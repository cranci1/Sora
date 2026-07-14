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
            Logger.shared.log("Failed to encode settings", type: "Error")
            return false
        }
        UserDefaults.standard.set(data, forKey: settingsStorageKey(for: module))
        
        do {
            try writeSettingsToFile(for: module)
            Logger.shared.log("File updated with new settings")
        } catch {
            Logger.shared.log("Failed to write settings to file: \(error)", type: "Error")
            return false
        }
        return true
    }
    
    private func settingsStorageKey(for module: ScrapingModule) -> String {
        "moduleSettings_\(module.id.uuidString)"
    }
    
    func loadSettingOverrides(for module: ScrapingModule) -> [String: String] {
        guard
            let data = UserDefaults.standard.data(forKey: settingsStorageKey(for: module)),
            let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }
    
    fileprivate static func parseSettingsSchema(from script: String) -> [ModuleSettingSchemaEntry] {
        guard let start = script.range(of: "// Settings start"),
              let end = script.range(of: "// Settings end", range: start.upperBound..<script.endIndex) else {
            return []
        }

        let block = String(script[start.upperBound..<end.lowerBound])
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false)
        var entries: [ModuleSettingSchemaEntry] = []

        let pattern = #"^const\s+(\w+)\s*=\s*(.+?);(?:\s*//\s*(.*))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty && !trimmed.hasPrefix("//") else { continue }

            let nsLine = trimmed as NSString
            guard let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: nsLine.length)) else { continue }

            let key = nsLine.substring(with: match.range(at: 1))
            let rawValue = nsLine.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
            let comment = match.range(at: 3).location != NSNotFound ? nsLine.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces) : nil

            var defaultValue = rawValue
            if (rawValue.hasPrefix("\"") && rawValue.hasSuffix("\"")) ||
               (rawValue.hasPrefix("'") && rawValue.hasSuffix("'")) {
                defaultValue = String(rawValue.dropFirst().dropLast())
            }

            let type: String
            if let _ = Int(defaultValue) {
                type = "int"
            } else if let _ = Double(defaultValue), defaultValue.contains(".") {
                type = "float"
            } else if defaultValue.lowercased() == "true" || defaultValue.lowercased() == "false" {
                type = "bool"
            } else {
                type = "string"
            }

            let entry = ModuleSettingSchemaEntry(
                key: key,
                type: type,
                comment: comment,
                defaultValue: defaultValue,
                options: nil
            )
            entries.append(entry)
        }
        return entries
    }
}
