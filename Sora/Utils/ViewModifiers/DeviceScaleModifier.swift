//
//  MediaInfoView.swift
//  Sora
//
//  Created by paul on 28/05/25.
//

import SwiftUI

struct DeviceScaleModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var scaleFactor: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return horizontalSizeClass == .regular ? 1.3 : 1.1
        }
        return 1.0
    }

    func body(content: Content) -> some View {
        GeometryReader { geo in
            content
                .scaleEffect(scaleFactor)
                .frame(
                    width: geo.size.width / scaleFactor,
                    height: geo.size.height / scaleFactor
                )
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

/*
struct DeviceScaleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content // does nothing for now
    }
}*/


extension View {
    func deviceScaled() -> some View {
        modifier(DeviceScaleModifier())
    }
} 
