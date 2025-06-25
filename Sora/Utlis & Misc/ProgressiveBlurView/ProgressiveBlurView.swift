//
//  ProgressiveBlurView.swift
//  SoraPrototype
//
//  Created by Inumaki on 26/04/2025.
//

import SwiftUI

struct ProgressiveBlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> CustomBlurView {
        let view = CustomBlurView()
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: CustomBlurView, context: Context) { }
}

class CustomBlurView: UIVisualEffectView {
    
    override init(effect: UIVisualEffect?) {
        super.init(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        removeFilters()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            DispatchQueue.main.async {
                self.removeFilters()
            }
        }
    }
    
    private func removeFilters() {
        if let filterLayer = layer.sublayers?.first {
            filterLayer.filters = []
        }
    }
}
