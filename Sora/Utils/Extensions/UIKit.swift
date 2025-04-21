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
