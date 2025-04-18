//
//  iCloudSyncManager.swift
//  Sulfur
//
//  Created by Francesco on 17/04/25.
//

import UIKit

class iCloudSyncManager {
    static let shared = iCloudSyncManager()
    
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
        "continueWatchingItems"
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
    
    @objc private func willEnterBackground() {
        syncToiCloud()
        syncModulesToiCloud()
    }
    
    private func syncFromiCloud() {
        let iCloud = NSUbiquitousKeyValueStore.default
        let defaults = UserDefaults.standard
        
        for key in defaultsToSync {
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
        
        for key in defaultsToSync {
            if let value = defaults.object(forKey: key) {
                iCloud.set(value, forKey: key)
            }
        }
        
        iCloud.synchronize()
    }
    
    @objc private func iCloudDidChangeExternally(_ notification: Notification) {
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
    
    @objc private func userDefaultsDidChange(_ notification: Notification) {
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
        DispatchQueue.global(qos: .background).async {
            guard let iCloudURL = self.ubiquityContainerURL else { return }
            let localModulesURL = self.getLocalModulesFileURL()
            let iCloudModulesURL = iCloudURL.appendingPathComponent(self.modulesFileName)
            do {
                guard FileManager.default.fileExists(atPath: iCloudModulesURL.path) else { return }
                
                let shouldCopy: Bool
                if FileManager.default.fileExists(atPath: localModulesURL.path) {
                    let localData = try Data(contentsOf: localModulesURL)
                    let iCloudData = try Data(contentsOf: iCloudModulesURL)
                    shouldCopy = localData != iCloudData
                } else {
                    shouldCopy = true
                }
                
                if shouldCopy {
                    if FileManager.default.fileExists(atPath: localModulesURL.path) {
                        try FileManager.default.removeItem(at: localModulesURL)
                    }
                    try FileManager.default.copyItem(at: iCloudModulesURL, to: localModulesURL)
                }
            } catch {
                Logger.shared.log("iCloud modules fetch error: \(error)", type: "Error")
            }
        }
    }
    
    private func getLocalModulesFileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(modulesFileName)
    }
}
