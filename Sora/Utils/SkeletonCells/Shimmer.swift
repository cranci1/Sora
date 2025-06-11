//
//  Shimmer.swift
//  Sora
//
//  Created by Francesco on 09/02/25.
//

import SwiftUI

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    @State private var isVisible: Bool = true
    
    func body(content: Content) -> some View {
        content
            .modifier(AnimatedMask(phase: phase, isVisible: isVisible))
            .onAppear {
                isVisible = true
                withAnimation(
                    Animation.linear(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1.5
                }
            }
            .onDisappear {
                isVisible = false
                phase = -1
            }
    }
    
    struct AnimatedMask: AnimatableModifier {
        var phase: CGFloat = 0
        let isVisible: Bool
        
        var animatableData: CGFloat {
            get { phase }
            set { 
                if isVisible {
                    phase = newValue
                }
            }
        }
        
        func body(content: Content) -> some View {
            content
                .overlay(
                    Group {
                        if isVisible && phase > -1 {
                            shimmerOverlay
                        } else {
                            EmptyView()
                        }
                    }
                )
                .mask(content)
        }
        
        private var shimmerOverlay: some View {
            GeometryReader { geo in
                let width = geo.size.width
                
                let shimmerStart = phase - 0.25
                let shimmerEnd = phase + 0.25
                
                Rectangle()
                    .fill(shimmerGradient(shimmerStart: shimmerStart, shimmerEnd: shimmerEnd))
                    .blur(radius: 8)
                    .rotationEffect(.degrees(20))
                    .offset(x: -width * 0.7 + width * 2 * phase)
            }
        }
        
        private func shimmerGradient(shimmerStart: CGFloat, shimmerEnd: CGFloat) -> LinearGradient {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: shimmerColor1, location: shimmerStart - 0.15),
                    .init(color: shimmerColor2, location: shimmerStart),
                    .init(color: shimmerColor3, location: phase),
                    .init(color: shimmerColor2, location: shimmerEnd),
                    .init(color: shimmerColor1, location: shimmerEnd + 0.15)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        
        private let shimmerColor1 = Color.white.opacity(0.05)
        private let shimmerColor2 = Color.white.opacity(0.25)
        private let shimmerColor3 = Color.white.opacity(0.85)
    }
}
