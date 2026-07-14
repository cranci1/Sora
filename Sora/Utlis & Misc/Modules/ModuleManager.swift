//
//  ModuleManager.swift
//  Sora
//
//  Created by Francesco on 26/01/25.
//

import Foundation

@MainActor
class ModuleManager: ObservableObject {
    static let shared = ModuleManager()
    
    @Published var modules: [ScrapingModule] = []
    @Published var selectedModuleChanged = false
    
    private let fileManager = FileManager.default
    private let modulesFileName = "modules.json"
    
    init() {
        let url = getModulesFilePath()
        if (!FileManager.default.fileExists(atPath: url.path)) {
            do {
                try "[]".write(to: url, atomically: true, encoding: .utf8)
                Logger.shared.log("Created empty modules file", type: "Info")
            } catch {
                Logger.shared.log("Failed to create modules file: \(error.localizedDescription)", type: "Error")
            }
        }
        loadModules()
        NotificationCenter.default.addObserver(self, selector: #selector(handleModulesSyncCompleted), name: .modulesSyncDidComplete, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleModulesSyncCompleted() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let url = self.getModulesFilePath()
            guard FileManager.default.fileExists(atPath: url.path) else {
                Logger.shared.log("No modules file found after sync", type: "Error")
                self.modules = []
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                let decodedModules = try JSONDecoder().decode([ScrapingModule].self, from: data)
                self.modules = decodedModules
                
                Task {
                    await self.checkJSModuleFiles()
                }
                Logger.shared.log("Reloaded modules after iCloud sync")
            } catch {
                Logger.shared.log("Error handling modules sync: \(error.localizedDescription)", type: "Error")
                self.modules = []
            }
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func getModulesFilePath() -> URL {
        getDocumentsDirectory().appendingPathComponent(modulesFileName)
    }
    
    func loadModules() {
        let url = getModulesFilePath()
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.shared.log("Modules file does not exist, creating empty one", type: "Info")
            do {
                try "[]".write(to: url, atomically: true, encoding: .utf8)
                modules = []
            } catch {
                Logger.shared.log("Failed to create modules file: \(error.localizedDescription)", type: "Error")
                modules = []
            }
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            do {
                let decodedModules = try JSONDecoder().decode([ScrapingModule].self, from: data)
                modules = decodedModules
                
                Task {
                    await checkJSModuleFiles()
                }
            } catch {
                Logger.shared.log("Failed to decode modules: \(error.localizedDescription)", type: "Error")
                try "[]".write(to: url, atomically: true, encoding: .utf8)
                modules = []
            }
        } catch {
            Logger.shared.log("Failed to load modules file: \(error.localizedDescription)", type: "Error")
            modules = []
        }
    }
    
    func checkJSModuleFiles() async {
        Logger.shared.log("Checking JS module files...", type: "Info")
        var missingCount = 0
        
        for module in modules {
            let localUrl = getDocumentsDirectory().appendingPathComponent(module.localPath)
            if !fileManager.fileExists(atPath: localUrl.path) {
                missingCount += 1
                do {
                    guard let scriptUrl = URL(string: module.metadata.scriptUrl) else {
                        Logger.shared.log("Invalid script URL for module: \(module.metadata.sourceName)", type: "Error")
                        continue
                    }
                    
                    Logger.shared.log("Downloading missing JS file for: \(module.metadata.sourceName)", type: "Info")
                    
                    let (scriptData, _) = try await URLSession.custom.data(from: scriptUrl)
                    guard let jsContent = String(data: scriptData, encoding: .utf8) else {
                        Logger.shared.log("Invalid script encoding for module: \(module.metadata.sourceName)", type: "Error")
                        continue
                    }
                    
                    try jsContent.write(to: localUrl, atomically: true, encoding: .utf8)
                    Logger.shared.log("Successfully downloaded JS file for module: \(module.metadata.sourceName)")
                } catch {
                    Logger.shared.log("Failed to download JS file for module: \(module.metadata.sourceName) - \(error.localizedDescription)", type: "Error")
                }
            }
        }
        
        if missingCount > 0 {
            Logger.shared.log("Downloaded \(missingCount) missing module JS files", type: "Info")
        } else {
            Logger.shared.log("All module JS files are present", type: "Info")
        }
    }
    
    private func saveModules() {
        DispatchQueue.main.async {
            let url = self.getModulesFilePath()
            guard let data = try? JSONEncoder().encode(self.modules) else { return }
            try? data.write(to: url)
        }
    }
    
    func addModule(metadataUrl: String) async throws -> ScrapingModule {
        guard let url = URL(string: metadataUrl) else {
            throw NSError(domain: "Invalid metadata URL", code: -1)
        }
        
        if modules.contains(where: { $0.metadataUrl == metadataUrl }) {
            throw NSError(domain: "Module already exists", code: -1)
        }
        
        let (metadataData, _) = try await URLSession.custom.data(from: url)
        let metadata = try JSONDecoder().decode(ModuleMetadata.self, from: metadataData)
        
        guard let scriptUrl = URL(string: metadata.scriptUrl) else {
            throw NSError(domain: "Invalid script URL", code: -1)
        }
        
        let (scriptData, _) = try await URLSession.custom.data(from: scriptUrl)
        guard let jsContent = String(data: scriptData, encoding: .utf8) else {
            throw NSError(domain: "Invalid script encoding", code: -1)
        }
        
        let fileName = "\(UUID().uuidString).js"
        let localUrl = getDocumentsDirectory().appendingPathComponent(fileName)
        try jsContent.write(to: localUrl, atomically: true, encoding: .utf8)
        
        let module = ScrapingModule(
            metadata: metadata,
            localPath: fileName,
            metadataUrl: metadataUrl
        )
        
        DispatchQueue.main.async {
            self.modules.append(module)
            self.saveModules()
            self.selectedModuleChanged = true
            Logger.shared.log("Added module: \(module.metadata.sourceName)")
        }
        
        return module
    }
    
    func deleteModule(_ module: ScrapingModule) {
        let localUrl = getDocumentsDirectory().appendingPathComponent(module.localPath)
        try? fileManager.removeItem(at: localUrl)
        
        modules.removeAll { $0.id == module.id }
        saveModules()
        Logger.shared.log("Deleted module: \(module.metadata.sourceName)")
        
        NotificationCenter.default.post(name: .moduleRemoved, object: module.id.uuidString)
    }
    
    func getModuleContent(_ module: ScrapingModule) throws -> String {
        let localUrl = getDocumentsDirectory().appendingPathComponent(module.localPath)
        return try String(contentsOf: localUrl, encoding: .utf8)
    }
    
    func refreshModules() async {
        let modulesCopy = modules
        var updatedModules: [(Int, ScrapingModule)] = []
        
        for (index, module) in modulesCopy.enumerated() {
            do {
                guard let metadataUrl = URL(string: module.metadataUrl) else {
                    Logger.shared.log("Invalid metadata URL for module: \(module.metadata.sourceName)", type: "Error")
                    continue
                }
                
                let (metadataData, _) = try await URLSession.custom.data(from: metadataUrl)
                let newMetadata = try JSONDecoder().decode(ModuleMetadata.self, from: metadataData)
                
                if newMetadata.version != module.metadata.version {
                    guard let scriptUrl = URL(string: newMetadata.scriptUrl) else {
                        throw NSError(domain: "Invalid script URL", code: -1)
                    }
                    
                    let (scriptData, _) = try await URLSession.custom.data(from: scriptUrl)
                    guard let jsContent = String(data: scriptData, encoding: .utf8) else {
                        throw NSError(domain: "Invalid script encoding", code: -1)
                    }
                    
                    let localUrl = getDocumentsDirectory().appendingPathComponent(module.localPath)
                    try jsContent.write(to: localUrl, atomically: true, encoding: .utf8)
                    
                    let updatedModule = ScrapingModule(
                        id: module.id,
                        metadata: newMetadata,
                        localPath: module.localPath,
                        metadataUrl: module.metadataUrl,
                        isActive: module.isActive
                    )
                    
                    updatedModules.append((index, updatedModule))
                    try jsContent.write(to: localUrl, atomically: true, encoding: .utf8)
                    try? writeSettingsToFile(for: updatedModule)
                    Logger.shared.log("Prepared update for module: \(module.metadata.sourceName) to version \(newMetadata.version)")
                }
            } catch {
                Logger.shared.log("Failed to refresh module: \(module.metadata.sourceName) - \(error.localizedDescription)")
            }
        }
        
        if !updatedModules.isEmpty {
            for (index, updatedModule) in updatedModules {
                if index < modules.count {
                    modules[index] = updatedModule
                }
            }
            saveModules()
            Logger.shared.log("Successfully updated \(updatedModules.count) modules")
        }
    }
    
    func writeSettingsToFile(for module: ScrapingModule) throws {
        let url = getDocumentsDirectory().appendingPathComponent(module.localPath)
        var content = try String(contentsOf: url, encoding: .utf8)
        let overrides = loadSettingOverrides(for: module)
        guard !overrides.isEmpty else { return }
        
        for (key, value) in overrides {
            let pattern = #"^(\s*)const\s+\#(key)\s*=\s*.*?;(.*)$"#
            let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
            let range = NSRange(location: 0, length: content.utf16.count)
            let newLine = "$1const \(key) = \(formatForJS(value));$2"
            content = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: newLine)
        }

        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func formatForJS(_ value: String) -> String {
        if let _ = Int(value) { return value }
        if let _ = Double(value) { return value }
        if value.lowercased() == "true" || value.lowercased() == "false" { return value.lowercased() }
        
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
