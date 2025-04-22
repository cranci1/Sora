//
//  ExploreView.swift
//  Sulfur
//
//  Created by Dominic on 22.04.25.
//

import SwiftUI

struct SettingsView: View {
    @FocusState private var focusedSetting: Int?
    private let screenWidth = UIScreen.main.bounds.width

    var body: some View {
        HStack(spacing: 0) {
            VStack {
                Group {
                    RoundedRectangle(cornerRadius: 90, style: .circular)
                        .fill(.gray.opacity(0.3))
                        .frame(width: UIScreen.main.bounds.width * 0.3, height: UIScreen.main.bounds.width * 0.3)
                        .shadow(radius: 12)
                }
            }
            .frame(width: screenWidth / 2.0)

            VStack {
                ForEach(1..<7) { index in
                    Button(action: {
                        print("Selected Index: \(index)")
                    }) {
                        Text("Random Setting \(index)")
                            .frame(maxWidth: screenWidth / 2.5)
                            .scaleEffect(focusedSetting == index ? 1.0 : 0.85)
                            .animation(.easeInOut(duration: 0.2), value: focusedSetting == index)
                    }
                        .focused($focusedSetting, equals: index)
                }
            }
                .frame(width: screenWidth / 2.0)
        }
    }
}
