//
//  Notification+Name.swift
//  Sulfur
//
//  Created by Francesco on 17/04/25.
//

import Foundation

extension Notification.Name {
    static let iCloudSyncDidComplete = Notification.Name("iCloudSyncDidComplete")
    static let iCloudSyncDidFail = Notification.Name("iCloudSyncDidFail")
    static let ContinueWatchingDidUpdate = Notification.Name("ContinueWatchingDidUpdate")
    static let DownloadManagerStatusUpdate = Notification.Name("DownloadManagerStatusUpdate")
    static let modulesSyncDidComplete = Notification.Name("modulesSyncDidComplete")
}
