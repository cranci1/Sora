//
//  iCloudSyncManager.swift
//  Sulfur
//
//  Created by Francesco on 17/04/25.
//

import UIKit

// TODO: sync all profile user default suits
/*
     profileStore.profiles.forEach { profile in
         let suite = UserDefaults(suiteName: profile.id.uuidString)
         ...
     }
 */

// TODO: add migration for legacy app users without profiles
/*
    add all bookmarks and continue watching items to the first profile ?!
 */

// TODO: update "clear data" feature
// TODO: tests
class ICloudSyncManager {
    static let shared = ICloudSyncManager()

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
        "hideEmptySections",
        "multiThreads",
        "metadataProviders",
        "profilesData",
        "currentProfileID"
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
        NSUbiquitousKeyValueStore.default.synchronize()
        syncFromiCloud()
        syncModulesFromiCloud()
        NotificationCenter.default.addObserver(self, selector: #selector(iCloudDidChangeExternally), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default)
        NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
    }

    @objc
    private func willEnterBackground() {
        syncToiCloud()
        syncModulesToiCloud()
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

    private func syncFromiCloud() {
        let iCloud = NSUbiquitousKeyValueStore.default
        let defaults = UserDefaults.standard

        for key in allKeysToSync() {
            if let value = iCloud.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }

        defaults.synchronize()
        NotificationCenter.default.post(name: .iCloudSyncDidComplete, object: nil)
    }

    private func syncToiCloud() {
        let iCloud = NSUbiquitousKeyValueStore.default
        let defaults = UserDefaults.standard

        for key in allKeysToSync() {
            if let value = defaults.object(forKey: key) {
                iCloud.set(value, forKey: key)
            }
        }

        iCloud.synchronize()
    }

    @objc
    private func iCloudDidChangeExternally(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
                  return
              }
        if reason == NSUbiquitousKeyValueStoreServerChange ||
            reason == NSUbiquitousKeyValueStoreInitialSyncChange {
            syncFromiCloud()
            syncModulesFromiCloud()
        }
    }

    @objc
    private func userDefaultsDidChange(_ notification: Notification) {
        syncToiCloud()
    }

    func syncModulesToiCloud() {
        DispatchQueue.global(qos: .background).async {
            guard let iCloudURL = self.ubiquityContainerURL else { return }
            let localModulesURL = self.getLocalModulesFileURL()
            let iCloudModulesURL = iCloudURL.appendingPathComponent(self.modulesFileName)
            do {
                guard FileManager.default.fileExists(atPath: localModulesURL.path) else { return }

                let shouldCopy: Bool
                if FileManager.default.fileExists(atPath: iCloudModulesURL.path) {
                    let localData = try Data(contentsOf: localModulesURL)
                    let iCloudData = try Data(contentsOf: iCloudModulesURL)
                    shouldCopy = localData != iCloudData
                } else {
                    shouldCopy = true
                }

                if shouldCopy {
                    if FileManager.default.fileExists(atPath: iCloudModulesURL.path) {
                        try FileManager.default.removeItem(at: iCloudModulesURL)
                    }
                    try FileManager.default.copyItem(at: localModulesURL, to: iCloudModulesURL)
                }
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
