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
        #if !os(tvOS)
        let position: Drop.Position = .top
        
        let drop = Drop(
            title: title,
            subtitle: subtitle,
            icon: icon,
            position: position,
            duration: .seconds(duration)
        )
        Drops.show(drop)
        #endif
    }
}
