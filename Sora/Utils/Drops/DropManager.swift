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
    private var lastNotificationTime: Date?
    private var pendingDownloads: Int = 0
    private var notificationTimer: Timer?
    
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
    
    // New method for handling download notifications
    func downloadStarted(episodeNumber: Int) {
        pendingDownloads += 1
        
        // Cancel any existing timer
        notificationTimer?.invalidate()
        
        // Create a new timer that will show the notification after a short delay
        notificationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Check if we've hit the max concurrent downloads limit
            let activeDownloads = JSController.shared.activeDownloads.count
            let isQueued = activeDownloads >= JSController.shared.maxConcurrentDownloads
            
            let message = isQueued 
                ? "Episode \(episodeNumber) queued"
                : "Episode \(episodeNumber) download started"
            
            self.showDrop(
                title: isQueued ? "Download Queued" : "Download Started",
                subtitle: message,
                duration: 1.5,
                icon: UIImage(systemName: isQueued ? "clock.arrow.circlepath" : "arrow.down.circle.fill")
            )
            
            // Reset pending downloads after showing notification
            self.pendingDownloads = 0
        }
    }
}
