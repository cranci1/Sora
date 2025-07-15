//
//  DownloadPersistence.swift
//  Sora
//
//  iOS 15 JSON + UserDefaults persistence layer.
//

import Foundation

/// Where the master JSON lives
private var documentsDirectory: URL {
    FileManager.default.urls(for: .applicationSupportDirectory,
                             in: .userDomainMask).first!
        .appendingPathComponent("SoraDownloads")
}

/// Master JSON file name
private let jsonFileName = "downloads.json"

/// Light index in UserDefaults (UUID → file name, for instant look-ups)
private let defaultsKey = "downloadIndex"

/// Root object that is written to JSON
private struct DiskStore: Codable {
    var assets: [DownloadedAsset] = []
}

/// Singleton façade
enum DownloadPersistence {

    // MARK: - Public API

    /// Loads the entire catalogue
    static func load() -> [DownloadedAsset] {
        migrateIfNeeded()
        return readStore().assets
    }

    /// Saves the entire catalogue
    static func save(_ assets: [DownloadedAsset]) {
        writeStore(DiskStore(assets: assets))
        updateDefaultsIndex(from: assets)
    }

    /// Adds or replaces one asset
    static func upsert(_ asset: DownloadedAsset) {
        var assets = load()
        assets.removeAll { $0.id == asset.id }
        assets.append(asset)
        save(assets)
    }

    /// Deletes one asset
    static func delete(id: UUID) {
        var assets = load()
        assets.removeAll { $0.id == id }
        save(assets)
    }

    // MARK: - Internal helpers

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

    /// Keeps UserDefaults in sync: [UUID → file name]
    private static func updateDefaultsIndex(from assets: [DownloadedAsset]) {
        let dict = Dictionary(uniqueKeysWithValues:
            assets.map { ($0.id.uuidString, $0.localURL.lastPathComponent) })
        UserDefaults.standard.set(dict, forKey: defaultsKey)
    }

    // MARK: - One-time migration from old UserDefaults store

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
            // Remove old key to avoid bloat
            UserDefaults.standard.removeObject(forKey: "downloadedAssets")
        } catch {
            // Couldn’t decode – ignore and start fresh
            UserDefaults.standard.set(true, forKey: migrationDoneKey)
        }
    }
}