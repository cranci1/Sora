//
//  CircularProgressBar.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI

struct CircularProgressBar: View {
    var progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 5.0)
                .opacity(0.3)
                .foregroundColor(Color.accentColor)

            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 5.0, lineCap: .round, lineJoin: .round))
                .foregroundColor(Color.accentColor)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)

            if progress >= 0.9 {
                Image(systemName: "checkmark")
                    .font(.system(size: 12))
            } else {
                Text(String(format: "%.0f%%", min(progress, 1.0) * 100.0))
                    .font(.system(size: 12))
            }
        }
    }
}
