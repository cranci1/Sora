//
//  Shimmer.swift
//  Sora
//
//  Created by Francesco on 09/02/25.
//

import SwiftUI

enum ShimmerType: String, CaseIterable, Identifiable {
    case shimmer, pulse, none

    var id: String { self.rawValue }
}

struct ShimmeringEffect: ViewModifier {
    @EnvironmentObject var settings: Settings

    func body(content: Content) -> some View {
        switch settings.shimmerType {
        case .pulse:
            return AnyView(content.modifier(ShimmerPulse()))
        case .shimmer:
            return AnyView(content.modifier(ShimmerDefault()))
        default:
            return AnyView(content.modifier(ShimmerNone()))
        }
    }
}

struct ShimmerDefault: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.4), Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: self.phase * 350)
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

struct ShimmerPulse: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @State private var opacity = 0.3

    func body(content: Content) -> some View {
        content
            .overlay(
                (colorScheme == .light ?
                    Color.black.opacity(opacity) :
                    Color.white.opacity(opacity)
                )
                .blendMode(.overlay)
            )
            .mask(content)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    opacity = 0.8
                }
            }
    }
}

struct ShimmerNone: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .overlay(
                (colorScheme == .light ?
                    Color.black.opacity(0.3) :
                    Color.white.opacity(0.3)
                )
                .blendMode(.overlay)
            )
            .mask(content)
    }
}
