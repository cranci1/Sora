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
