//
//  Shimmer.swift
//  Sora
//
//  Created by Francesco on 09/02/25.
//

import SwiftUI

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .modifier(AnimatedMask(phase: phase).animation(
                Animation.linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
            ))
            .onAppear {
                phase = 0.8
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
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .clear, location: phase - 0.3),
                                        .init(color: .white.opacity(0.5), location: phase),
                                        .init(color: .clear, location: phase + 0.3)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .rotationEffect(.degrees(30))
                            .offset(x: -geo.size.width)
                            .offset(x: geo.size.width * 2 * phase)
                    }
                )
                .mask(content)
        }
    }
}
