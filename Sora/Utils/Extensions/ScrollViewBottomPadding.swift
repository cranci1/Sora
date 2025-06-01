//
//  ScrollViewBottomPadding.swift
//  Sora
//
//  Created by paul on 29/05/25.
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
        modifier(Shimmer())
    }

    func scrollViewBottomPadding() -> some View {
        modifier(ScrollViewBottomPadding())
    }
}
