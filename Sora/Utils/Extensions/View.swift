//
//  View.swift
//  Sora
//
//  Created by Francesco on 09/02/25.
//

import SwiftUI

struct ScrollViewBottomPadding: ViewModifier {
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: 60)
            }
    }
}

extension View {
    func shimmering() -> some View {
        self.modifier(Shimmer())
    }

    func scrollViewBottomPadding() -> some View {
        modifier(ScrollViewBottomPadding())
    }
}
