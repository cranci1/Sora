//
//  View.swift
//  Sora
//
//  Created by Francesco on 09/02/25.
//

import SwiftUI

extension View {
    func shimmering() -> some View {
        self.modifier(ShimmeringEffect())
    }
}

struct SeparatorAlignmentModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        } else {
            content
        }
    }
}

struct HideToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .toolbarVisibility(.hidden, for: .tabBar)
        } else if #available(iOS 16.0, *) {
            content
                .toolbar(.hidden, for: .tabBar)
        } else {
            content
        }
    }
}
