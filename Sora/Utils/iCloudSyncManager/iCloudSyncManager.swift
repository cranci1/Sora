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
    
    private init() {
        setupSync()
        
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterBackground), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    private func setupSync() {
        NSUbiquitousKeyValueStore.default.synchronize()
        
        syncFromiCloud()
        
        NotificationCenter.default.addObserver(self, selector: #selector(iCloudDidChangeExternally), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default)
        
        NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
    }
    
    @objc private func willEnterBackground() {
        syncToiCloud()
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
        }
    }
    
    @objc private func userDefaultsDidChange(_ notification: Notification) {
        syncToiCloud()
    }
}
