//
//  ModulesManager.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import Foundation

class ModulesManager: ObservableObject {
    @Published var modules: [ModuleStruct] = []
    @Published var isLoading = true
    var moduleURLs: [String: String] = [:]
    private let modulesFileName = "modules.json"
    private let moduleURLsFileName = "moduleURLs.json"
    
    init() {
        loadModules()
    }
    
    func loadModules() {
        isLoading = true
        loadModuleURLs()
        loadModuleData()
        isLoading = false
    }
    
    func addModule(from urlString: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(ModuleError.invalidURL))
            return
        }
        let task = URLSession.custom.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion(.failure(error ?? ModuleError.unknown))
                return
            }
            do {
                let module = try JSONDecoder().decode(ModuleStruct.self, from: data)
                DispatchQueue.main.async {
                    if !self.modules.contains(where: { $0.name == module.name }) {
                        self.modules.append(module)
                        self.moduleURLs[module.name] = urlString
                        self.saveModuleData()
                        self.saveModuleURLs()
                        NotificationCenter.default.post(name: .moduleAdded, object: nil)
                        completion(.success(()))
                    } else {
                        completion(.failure(ModuleError.duplicateModule))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    func deleteModule(named name: String) {
        if let index = modules.firstIndex(where: { $0.name == name }) {
            modules.remove(at: index)
            moduleURLs.removeValue(forKey: name)
            saveModuleData()
            saveModuleURLs()
            NotificationCenter.default.post(name: .moduleRemoved, object: nil)
        }
    }
    
    func refreshModules() {
        for (name, urlString) in moduleURLs {
            guard let url = URL(string: urlString) else { continue }
            let task = URLSession.custom.dataTask(with: url) { data, _, error in
                guard let data = data, error == nil else { return }
                do {
                    let updatedModule = try JSONDecoder().decode(ModuleStruct.self, from: data)
                    DispatchQueue.main.async {
                        if let index = self.modules.firstIndex(where: { $0.name == name }) {
                            self.modules[index] = updatedModule
                            self.saveModuleData()
                        }
                    }
                } catch {
                    print("Failed to decode module during refresh: \(error.localizedDescription)")
                    Logger.shared.log("Failed to decode module during refresh: \(error.localizedDescription)")
                }
            }
            task.resume()
        }
    }
    
    private func loadModuleURLs() {
        let fileURL = getDocumentsDirectory().appendingPathComponent(moduleURLsFileName)
        do {
            let data = try Data(contentsOf: fileURL)
            moduleURLs = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            print("Failed to load module URLs: \(error.localizedDescription)")
            Logger.shared.log("Failed to load module URLs: \(error.localizedDescription)")
        }
    }
    
    private func loadModuleData() {
        let fileURL = getDocumentsDirectory().appendingPathComponent(modulesFileName)
        do {
            let data = try Data(contentsOf: fileURL)
            modules = try JSONDecoder().decode([ModuleStruct].self, from: data)
        } catch {
            print("Failed to load modules: \(error.localizedDescription)")
            Logger.shared.log("Failed to load modules: \(error.localizedDescription)")
        }
    }
    
    func saveModuleData() {
        let fileURL = getDocumentsDirectory().appendingPathComponent(modulesFileName)
        do {
            let data = try JSONEncoder().encode(modules)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save modules: \(error.localizedDescription)")
            Logger.shared.log("Failed to save modules: \(error.localizedDescription)")
        }
    }
    
    private func saveModuleURLs() {
        let fileURL = getDocumentsDirectory().appendingPathComponent(moduleURLsFileName)
        do {
            let data = try JSONEncoder().encode(moduleURLs)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save module URLs: \(error.localizedDescription)")
            Logger.shared.log("Failed to save module URLs: \(error.localizedDescription)")
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func addModules(from urlStrings: String, completion: @escaping (Result<Int, Error>) -> Void) {
        let urls = urlStrings.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var successCount = 0
        let group = DispatchGroup()
        
        for urlString in urls {
            group.enter()
            addModule(from: urlString) { result in
                switch result {
                case .success:
                    successCount += 1
                case .failure:
                    break
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(.success(successCount))
        }
    }
    
    func exportModules() -> Data? {
        let exportData = ExportData(modules: modules, moduleURLs: moduleURLs)
        return try? JSONEncoder().encode(exportData)
    }
    
    func importModules(from data: Data) throws {
        let importData = try JSONDecoder().decode(ExportData.self, from: data)
        modules = importData.modules
        moduleURLs = importData.moduleURLs
        saveModuleData()
        saveModuleURLs()
        NotificationCenter.default.post(name: .moduleAdded, object: nil)
    }
    
    enum ModuleError: LocalizedError {
        case invalidURL
        case duplicateModule
        case unknown
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The provided URL is invalid."
            case .duplicateModule:
                return "This module already exists."
            case .unknown:
                return "An unknown error occurred."
            }
        }
    }
    
    private struct ExportData: Codable {
        let modules: [ModuleStruct]
        let moduleURLs: [String: String]
    }
}
