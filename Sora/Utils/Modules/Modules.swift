//
//  Modules.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import Foundation

struct ModuleMetadata: Codable, Hashable {
    let sourceName: String
    let author: String
    let iconUrl: String
    let version: String
    let language: String
    let baseUrl: String
    let searchBaseUrl: String
    let scriptUrl: String
    let asyncJS: Bool?
}

struct ScrapingModule: Codable, Identifiable, Hashable {
    let id: UUID
    let metadata: ModuleMetadata
    let localPath: String
    var isActive: Bool
    
    init(id: UUID = UUID(), metadata: ModuleMetadata, localPath: String, isActive: Bool = false) {
        self.id = id
        self.metadata = metadata
        self.localPath = localPath
        self.isActive = isActive
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ScrapingModule, rhs: ScrapingModule) -> Bool {
        lhs.id == rhs.id
    }
}

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
            localPath: fileName
        )
        
        DispatchQueue.main.async {
            self.modules.append(module)
            Logger.shared.log("Added module \(module.metadata.sourceName).", level: .info)
            self.saveModules()
        }
        
        return module
    }
    
    func deleteModule(_ module: ScrapingModule) {
        let localUrl = getDocumentsDirectory().appendingPathComponent(module.localPath)
        try? fileManager.removeItem(at: localUrl)
        
        modules.removeAll { $0.id == module.id }
        saveModules()
        Logger.shared.log("Deleted module \(module.metadata.sourceName).", level: .info)
    }
    
    func getModuleContent(_ module: ScrapingModule) throws -> String {
        let localUrl = getDocumentsDirectory().appendingPathComponent(module.localPath)
        return try String(contentsOf: localUrl, encoding: .utf8)
    }
}
