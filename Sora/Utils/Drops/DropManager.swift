//
//  DropManager.swift
//  Sora
//
//  Created by Francesco on 25/01/25.
//

import Drops
import UIKit

class DropManager {
    static let shared = DropManager()
    
    private var notificationQueue: [(title: String, subtitle: String, duration: TimeInterval, icon: UIImage?)] = []
    private var isProcessingQueue = false
    
    private init() {}
    
    func showDrop(title: String, subtitle: String, duration: TimeInterval, icon: UIImage?) {
        // Add to queue
        notificationQueue.append((title: title, subtitle: subtitle, duration: duration, icon: icon))
        
        // Process queue if not already processing
        if !isProcessingQueue {
            processQueue()
        }
    }
    
    private func processQueue() {
        guard !notificationQueue.isEmpty else {
            isProcessingQueue = false
            return
        }
        
        isProcessingQueue = true
        
        // Get the next notification
        let notification = notificationQueue.removeFirst()
        
        // Show the notification
        let drop = Drop(
            title: notification.title,
            subtitle: notification.subtitle,
            icon: notification.icon,
            position: .top,
            duration: .seconds(notification.duration)
        )
        
        Drops.show(drop)
        
        // Schedule next notification
        DispatchQueue.main.asyncAfter(deadline: .now() + notification.duration) { [weak self] in
            self?.processQueue()
        }
    }
    
    func success(_ message: String, duration: TimeInterval = 2.0) {
        let icon = UIImage(systemName: "checkmark.circle.fill")?.withTintColor(.green, renderingMode: .alwaysOriginal)
        showDrop(title: "Success", subtitle: message, duration: duration, icon: icon)
    }
    
    func error(_ message: String, duration: TimeInterval = 2.0) {
        let icon = UIImage(systemName: "xmark.circle.fill")?.withTintColor(.red, renderingMode: .alwaysOriginal)
        showDrop(title: "Error", subtitle: message, duration: duration, icon: icon)
    }
    
    func info(_ message: String, duration: TimeInterval = 2.0) {
        let icon = UIImage(systemName: "info.circle.fill")?.withTintColor(.blue, renderingMode: .alwaysOriginal)
        showDrop(title: "Info", subtitle: message, duration: duration, icon: icon)
    }
    
    // Method for handling download notifications with accurate status determination
    func downloadStarted(episodeNumber: Int) {
        // Use the JSController method to accurately determine if download will start immediately
        let willStartImmediately = JSController.shared.willDownloadStartImmediately()
        
        let message = willStartImmediately 
            ? "Episode \(episodeNumber) download started"
            : "Episode \(episodeNumber) queued"
        
        showDrop(
            title: willStartImmediately ? "Download Started" : "Download Queued",
            subtitle: message,
            duration: 1.5,
            icon: UIImage(systemName: willStartImmediately ? "arrow.down.circle.fill" : "clock.arrow.circlepath")
        )
    }
}
