//
//  Notification+Name.swift
//  Sulfur
//
//  Created by Francesco on 17/04/25.
//

import Foundation
import UIKit

extension Notification.Name {
    static let iCloudSyncDidComplete = Notification.Name("iCloudSyncDidComplete")
    static let iCloudSyncDidFail = Notification.Name("iCloudSyncDidFail")
    static let ContinueWatchingDidUpdate = Notification.Name("ContinueWatchingDidUpdate")
    static let DownloadManagerStatusUpdate = Notification.Name("DownloadManagerStatusUpdate")
    static let modulesSyncDidComplete = Notification.Name("modulesSyncDidComplete")
    static let moduleRemoved = Notification.Name("moduleRemoved")
    static let didReceiveNewModule = Notification.Name("didReceiveNewModule")
    static let didUpdateModules = Notification.Name("didUpdateModules")
    static let didUpdateDownloads = Notification.Name("didUpdateDownloads")
    static let didUpdateBookmarks = Notification.Name("didUpdateBookmarks")
    static let hideTabBar = Notification.Name("hideTabBar")
    static let showTabBar = Notification.Name("showTabBar")
    static let searchQueryChanged = Notification.Name("searchQueryChanged")
}
