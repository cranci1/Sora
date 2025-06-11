//
//  SplashScreenView.swift
//  Sora
//
//  Created by paul on 11/06/25.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var showMainApp = false
    
    var body: some View {
        ZStack {
            if showMainApp {
                ContentView()
            } else {
                VStack {
                    Image("SplashScreenIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .cornerRadius(24)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .opacity(isAnimating ? 1.0 : 0.0)
                    
                    Text("Sora")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .opacity(isAnimating ? 1.0 : 0.0)
                }
                .onAppear {
                    withAnimation(.easeIn(duration: 0.5)) {
                        isAnimating = true
                    }
                    
                    // Transition to main app after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showMainApp = true
                        }
                    }
                }
            }
        }
    }
} 