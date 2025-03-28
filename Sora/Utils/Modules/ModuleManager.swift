//
//  ModuleManager.swift
//  Sora
//
//  Created by Francesco on 26/01/25.
//

import Foundation

class ModuleManager: ObservableObject {
    @Published var modules: [ScrapingModule] = []
    
    private let fileManager = FileManager.default
    private let modulesFileName = "modules.json"
    
    init() {
        loadModules()
    }
    
    private func getDocumentsDirectory() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func getModulesFilePath() -> URL {
        getDocumentsDirectory().appendingPathComponent(modulesFileName)
    }
    
    func loadModules() {
        let url = getModulesFilePath()
        guard let data = try? Data(contentsOf: url) else { return }
        modules = (try? JSONDecoder().decode([ScrapingModule].self, from: data)) ?? []
    }
    
    private func saveModules() {
        let url = getModulesFilePath()
        guard let data = try? JSONEncoder().encode(modules) else { return }
        try? data.write(to: url)
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
    }
    
    func getModuleContent(_ module: ScrapingModule) throws -> String {
        let localUrl = getDocumentsDirectory().appendingPathComponent(module.localPath)
        return try String(contentsOf: localUrl, encoding: .utf8)
    }
    
    func refreshModules() async {
        for (index, module) in modules.enumerated() {
            do {
                let (metadataData, _) = try await URLSession.custom.data(from: URL(string: module.metadataUrl)!)
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
                    
                    await MainActor.run {
                        self.modules[index] = updatedModule
                        self.saveModules()
                    }
                    
                    Logger.shared.log("Updated module: \(module.metadata.sourceName) to version \(newMetadata.version)")
                }
            } catch {
                Logger.shared.log("Failed to refresh module: \(module.metadata.sourceName) - \(error.localizedDescription)")
            }
        }
    }
}
