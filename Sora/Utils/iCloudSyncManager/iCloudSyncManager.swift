//
//  iCloudSyncManager.swift
//  Sulfur
//
//  Created by Francesco on 17/04/25.
//

import UIKit

class iCloudSyncManager {
    static let shared = iCloudSyncManager()
    
    private let syncQueue = DispatchQueue(label: "me.cranci.sora.icloud-sync", qos: .utility)
    private let defaultsToSync: [String] = [
        "externalPlayer",
        "alwaysLandscape",
        "rememberPlaySpeed",
        "holdSpeedPlayer",
        "skipIncrement",
        "skipIncrementHold",
        "holdForPauseEnabled",
        "skip85Visible",
        "doubleTapSeekEnabled",
        "selectedModuleId",
        "mediaColumnsPortrait",
        "mediaColumnsLandscape",
        "sendPushUpdates",
        "sendTraktUpdates",
        "bookmarkedItems",
        "continueWatchingItems",
        "analyticsEnabled",
        "refreshModulesOnLaunch",
        "fetchEpisodeMetadata",
        "multiThreads",
        "metadataProviders"
    ]
    
    private let modulesFileName = "modules.json"
    
    private var ubiquityContainerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }
    
    private init() {
        setupSync()
        
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterBackground), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    private func setupSync() {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            NSUbiquitousKeyValueStore.default.synchronize()
            self.syncFromiCloud()
            self.syncModulesFromiCloud()
            
            DispatchQueue.main.async {
                NotificationCenter.default.addObserver(self, selector: #selector(self.iCloudDidChangeExternally), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default)
                NotificationCenter.default.addObserver(self, selector: #selector(self.userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
            }
        }
    }
    
    @objc private func iCloudDidChangeExternally(_ notification: NSNotification) {
        guard let iCloud = notification.object as? NSUbiquitousKeyValueStore,
              let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
                  Logger.shared.log("Invalid iCloud notification data", type: "Error")
                  return
              }
        
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            let defaults = UserDefaults.standard
            for key in changedKeys {
                if let value = iCloud.object(forKey: key), self.isValidValueType(value) {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
            
            defaults.synchronize()
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .iCloudSyncDidComplete, object: nil)
            }
        }
    }
    
    @objc private func userDefaultsDidChange(_ notification: Notification) {
        syncQueue.async { [weak self] in
            self?.syncToiCloud()
        }
    }
    
    func syncToiCloud(item: SyncItem) {
        let queue = DispatchQueue(label: "me.cranci.sora.icloud-sync")
        
        queue.async {
            do {
                let container = NSUbiquitousKeyValueStore.default
                
                let encoder = JSONEncoder()
                let data = try encoder.encode(item)
                
                if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    container.set(dict, forKey: "syncedItems")
                    container.synchronize()
                }
            } catch {
                Logger.shared.log("Failed to sync to iCloud: \(error.localizedDescription)", type: "Error")
            }
        }
    }
    
    private func syncFromiCloud() {
        let iCloud = NSUbiquitousKeyValueStore.default
        let defaults = UserDefaults.standard
        
        for key in allKeysToSync() {
            if let value = iCloud.object(forKey: key) {
                if isValidValueType(value) {
                    defaults.set(value, forKey: key)
                }
            }
        }
        
        defaults.synchronize()
        NotificationCenter.default.post(name: .iCloudSyncDidComplete, object: nil)
    }
    
    private func isValidValueType(_ value: Any) -> Bool {
        return value is String ||
        value is Bool ||
        value is Int ||
        value is Float ||
        value is Double ||
        value is Data ||
        value is Date ||
        value is [Any] ||
        value is [String: Any]
    }
    
    @objc private func willEnterBackground() {
        syncQueue.async { [weak self] in
            self?.syncToiCloud()
            self?.syncModulesToiCloud()
        }
    }
    
    private func allProgressKeys() -> [String] {
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        let progressPrefixes = ["lastPlayedTime_", "totalTime_"]
        return allKeys.filter { key in
            progressPrefixes.contains { prefix in key.hasPrefix(prefix) }
        }
    }
    
    private func allKeysToSync() -> [String] {
        var keys = Set(defaultsToSync + allProgressKeys())
        let userDefaults = UserDefaults.standard
        let all = userDefaults.dictionaryRepresentation()
        for (key, value) in all {
            if key.hasPrefix("Apple") || key.hasPrefix("_") { continue }
            if value is Int || value is Double || value is Bool || value is String {
                keys.insert(key)
            }
        }
        return Array(keys)
    }
    
    func syncModulesToiCloud() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, let iCloudURL = self.ubiquityContainerURL else { return }
            
            let localModulesURL = self.getLocalModulesFileURL()
            let iCloudModulesURL = iCloudURL.appendingPathComponent(self.modulesFileName)
            
            do {
                guard FileManager.default.fileExists(atPath: localModulesURL.path) else { return }
                
                let localData = try Data(contentsOf: localModulesURL)
                let _ = try JSONSerialization.jsonObject(with: localData, options: [])
                
                if FileManager.default.fileExists(atPath: iCloudModulesURL.path) {
                    try FileManager.default.removeItem(at: iCloudModulesURL)
                }
                try FileManager.default.copyItem(at: localModulesURL, to: iCloudModulesURL)
                
            } catch {
                Logger.shared.log("iCloud modules sync error: \(error)", type: "Error")
            }
        }
    }
    
    func syncModulesFromiCloud() {
        guard let iCloudURL = self.ubiquityContainerURL else {
            Logger.shared.log("iCloud container not available", type: "Error")
            return
        }
        
        let localModulesURL = self.getLocalModulesFileURL()
        let iCloudModulesURL = iCloudURL.appendingPathComponent(self.modulesFileName)
        
        do {
            if !FileManager.default.fileExists(atPath: iCloudModulesURL.path) {
                Logger.shared.log("No modules file found in iCloud", type: "Info")
                
                if FileManager.default.fileExists(atPath: localModulesURL.path) {
                    Logger.shared.log("Copying local modules file to iCloud", type: "Info")
                    try FileManager.default.copyItem(at: localModulesURL, to: iCloudModulesURL)
                } else {
                    Logger.shared.log("Creating new empty modules file in iCloud", type: "Info")
                    let emptyModules: [ScrapingModule] = []
                    let emptyData = try JSONEncoder().encode(emptyModules)
                    try emptyData.write(to: iCloudModulesURL)
                    
                    try emptyData.write(to: localModulesURL)
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .modulesSyncDidComplete, object: nil)
                    }
                }
                return
            }
            
            let shouldCopy: Bool
            if FileManager.default.fileExists(atPath: localModulesURL.path) {
                let localData = try Data(contentsOf: localModulesURL)
                let iCloudData = try Data(contentsOf: iCloudModulesURL)
                shouldCopy = localData != iCloudData
            } else {
                shouldCopy = true
            }
            
            if shouldCopy {
                Logger.shared.log("Syncing modules from iCloud", type: "Info")
                if FileManager.default.fileExists(atPath: localModulesURL.path) {
                    try FileManager.default.removeItem(at: localModulesURL)
                }
                try FileManager.default.copyItem(at: iCloudModulesURL, to: localModulesURL)
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .modulesSyncDidComplete, object: nil)
                }
            }
        } catch {
            Logger.shared.log("iCloud modules sync error: \(error)", type: "Error")
        }
    }
    
    private func getLocalModulesFileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(modulesFileName)
    }
}
