//
//  Shimmer.swift
//  Sora
//
//  Created by Francesco on 09/02/25.
//

import SwiftUI

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    
    func body(content: Content) -> some View {
        content
            .modifier(AnimatedMask(phase: phase)
                        .animation(
                            Animation.linear(duration: 1.2)
                                .repeatForever(autoreverses: false)
                        )
            )
            .onAppear {
                phase = 1.5
            }
    }
    
    struct AnimatedMask: AnimatableModifier {
        var phase: CGFloat = 0
        
        var animatableData: CGFloat {
            get { phase }
            set { phase = newValue }
        }
        
        func body(content: Content) -> some View {
            content
                .overlay(
                    GeometryReader { geo in
                        let width = geo.size.width
                        let shimmerStart = phase - 0.25
                        let shimmerEnd = phase + 0.25
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.white.opacity(0.05), location: shimmerStart - 0.15),
                                        .init(color: Color.white.opacity(0.25), location: shimmerStart),
                                        .init(color: Color.white.opacity(0.85), location: phase),
                                        .init(color: Color.white.opacity(0.25), location: shimmerEnd),
                                        .init(color: Color.white.opacity(0.05), location: shimmerEnd + 0.15)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .blur(radius: 8)
                            .rotationEffect(.degrees(20))
                            .offset(x: -width * 0.7 + width * 2 * phase)
                    }
                )
                .mask(content)
        }
    }
}
