//
//  finTopView.swift
//  Sulfur
//
//  Created by Francesco on 04/03/25.
//

import UIKit

class findTopViewController {
    static func findViewController(_ viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return findViewController(presented)
        }
        
        if let navigationController = viewController as? UINavigationController {
            return findViewController(navigationController.visibleViewController ?? navigationController)
        }
        
        if let tabBarController = viewController as? UITabBarController,
           let selected = tabBarController.selectedViewController {
            return findViewController(selected)
        }
        
        return viewController
    }
}
