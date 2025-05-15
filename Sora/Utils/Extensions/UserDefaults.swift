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
}
