import SwiftUI

public struct ScrollViewBottomPadding: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: 100) // Height that accounts for tab bar + padding
            }
    }
}

public extension View {
    func scrollViewBottomPadding() -> some View {
        modifier(ScrollViewBottomPadding())
    }
} 