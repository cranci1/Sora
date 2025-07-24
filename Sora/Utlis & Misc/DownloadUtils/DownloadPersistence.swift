//
//  DownloadPersistence.swift
//  Sulfur
//
//  Created by doomsboygaming on 15/07/25.
//

import Foundation

private var documentsDirectory: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("SoraDownloads")
}

private let jsonFileName = "downloads.json"
private let defaultsKey = "downloadIndex"

private struct DiskStore: Codable {
    var assets: [DownloadedAsset] = []
}

enum DownloadPersistence {
    static func load() -> [DownloadedAsset] {
        migrateIfNeeded()
        return readStore().assets
    }
    
    static func save(_ assets: [DownloadedAsset]) {
        writeStore(DiskStore(assets: assets))
        updateDefaultsIndex(from: assets)
    }
    
    static func upsert(_ asset: DownloadedAsset) {
        var assets = load()
        assets.removeAll { $0.id == asset.id }
        assets.append(asset)
        save(assets)
    }
    
    static func delete(id: UUID) {
        var assets = load()
        assets.removeAll { $0.id == id }
        save(assets)
    }
    
    static func orphanedFiles() -> [URL] {
        let fileManager = FileManager.default
        let downloadsDir = documentsDirectory
        let jsonFile = downloadsDir.appendingPathComponent(jsonFileName)
        let persistedAssets = load()
        let referencedPaths = Set(persistedAssets.compactMap { [$0.localURL.lastPathComponent] + ($0.localSubtitleURL != nil ? [$0.localSubtitleURL!.lastPathComponent] : []) }.flatMap { $0 })
        var orphaned: [URL] = []
        do {
            let files = try fileManager.contentsOfDirectory(at: downloadsDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for file in files {
                let name = file.lastPathComponent
                if name == jsonFileName { continue }
                if !referencedPaths.contains(name) {
                    orphaned.append(file)
                }
            }
        } catch {
        }
        return orphaned
    }
    
    private static func readStore() -> DiskStore {
        let url = documentsDirectory.appendingPathComponent(jsonFileName)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(DiskStore.self, from: data)
        else { return DiskStore() }
        return decoded
    }
    
    private static func writeStore(_ store: DiskStore) {
        try? FileManager.default.createDirectory(at: documentsDirectory,
                                                 withIntermediateDirectories: true)
        let url = documentsDirectory.appendingPathComponent(jsonFileName)
        guard let data = try? JSONEncoder().encode(store) else { return }
        try? data.write(to: url)
    }
    
    private static func updateDefaultsIndex(from assets: [DownloadedAsset]) {
        let dict = Dictionary(uniqueKeysWithValues:
                                assets.map { ($0.id.uuidString, $0.localURL.lastPathComponent) })
        UserDefaults.standard.set(dict, forKey: defaultsKey)
    }
    
    private static var migrationDoneKey = "migrationToJSONDone"
    
    private static func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationDoneKey),
              let oldData = UserDefaults.standard.data(forKey: "downloadedAssets") else {
            return
        }
        
        do {
            let oldAssets = try JSONDecoder().decode([DownloadedAsset].self, from: oldData)
            save(oldAssets)
            UserDefaults.standard.set(true, forKey: migrationDoneKey)
            UserDefaults.standard.removeObject(forKey: "downloadedAssets")
        } catch {
            UserDefaults.standard.set(true, forKey: migrationDoneKey)
        }
    }
}
