//
//  UIApplication.swift
//  Sulfur
//
//  Created by Dominic on 21.04.25.
//

import UIKit

extension UIApplication {
    func dismissKeyboard(_ force: Bool) {
        if #unavailable(iOS 15) {
            windows.first?.endEditing(force)
        } else {
            guard let windowScene = connectedScenes.first as? UIWindowScene else { return }
            windowScene.windows.first?.endEditing(force)
        }
    }
}

extension Decodable where Self: UIColor {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let components = try container.decode([CGFloat].self)
        self = Self.init(red: components[0], green: components[1], blue: components[2], alpha: components[3])
    }
}

extension Encodable where Self: UIColor {
    public func encode(to encoder: Encoder) throws {
        var r, g, b, a: CGFloat
        (r, g, b, a) = (0, 0, 0, 0)
        var container = encoder.singleValueContainer()
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        try container.encode([r, g, b, a])
    }
}

extension UIColor: Codable { }
