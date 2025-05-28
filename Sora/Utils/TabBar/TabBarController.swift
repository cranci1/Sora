//
//  TabBarController.swift
//  Sulfur
//
//  Created by Mac on 28/05/2025.
//

import SwiftUI

class TabBarController: ObservableObject {
    @Published var isHidden = false
    
    func hideTabBar() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isHidden = true
        }
    }
    
    func showTabBar() {
        withAnimation(.easeInOut(duration: 0.10)) {
            isHidden = false
        }
    }
}
