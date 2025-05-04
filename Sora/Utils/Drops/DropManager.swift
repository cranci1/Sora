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
    
    private init() {}
    
    func showDrop(title: String, subtitle: String, duration: TimeInterval, icon: UIImage?) {
        let position: Drop.Position = .top
        
        let drop = Drop(
            title: title,
            subtitle: subtitle,
            icon: icon,
            position: position,
            duration: .seconds(duration)
        )
        Drops.show(drop)
    }
    
    func success(_ message: String, duration: TimeInterval = 3.0) {
        let icon = UIImage(systemName: "checkmark.circle.fill")?.withTintColor(.green, renderingMode: .alwaysOriginal)
        showDrop(title: "Success", subtitle: message, duration: duration, icon: icon)
    }
    
    func error(_ message: String, duration: TimeInterval = 3.0) {
        let icon = UIImage(systemName: "xmark.circle.fill")?.withTintColor(.red, renderingMode: .alwaysOriginal)
        showDrop(title: "Error", subtitle: message, duration: duration, icon: icon)
    }
    
    func info(_ message: String, duration: TimeInterval = 3.0) {
        let icon = UIImage(systemName: "info.circle.fill")?.withTintColor(.blue, renderingMode: .alwaysOriginal)
        showDrop(title: "Info", subtitle: message, duration: duration, icon: icon)
    }
}
