//
//  UserDefaults.swift
//  Sulfur
//
//  Created by Francesco on 11/05/25.
//

import UIKit

extension UserDefaults {
    func color(forKey key: String) -> UIColor? {
        guard let colorData = data(forKey: key) else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData)
        } catch {
            return nil
        }
    }
    
    func set(_ color: UIColor?, forKey key: String) {
        guard let color = color else {
            removeObject(forKey: key)
            return
        }
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
            set(data, forKey: key)
        } catch {
            print("Error archiving color: \(error)")
        }
    }
}
