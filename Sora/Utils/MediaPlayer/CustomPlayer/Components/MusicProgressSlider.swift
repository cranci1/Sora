//
//  MusicProgressSlider.swift
//  Custom Seekbar
//
//  Created by Pratik on 08/01/23.
//
//  Thanks to pratikg29 for this code inside his open source project "https://github.com/pratikg29/Custom-Slider-Control?ref=iosexample.com"
//  I did edit some of the code for my liking (added a buffer indicator, etc.)

import SwiftUI

struct MusicProgressSlider<T: BinaryFloatingPoint>: View {
    @Binding var value: T
    @Binding var bufferValue: T                // NEW
    let inRange: ClosedRange<T>
    
    let activeFillColor: Color
    let fillColor: Color
    let emptyColor: Color
    let height: CGFloat
    
    let onEditingChanged: (Bool) -> Void
    
    @State private var localRealProgress: T = 0
    @State private var localTempProgress: T = 0
    @GestureState private var isActive: Bool = false
    
    var body: some View {
        GeometryReader { bounds in
            ZStack {
                VStack {
                    // Base track + buffer indicator + current progress
                    ZStack(alignment: .center) {
                        
                        // Entire background track
                        Capsule()
                            .fill(emptyColor)
                        
                        // 1) The buffer fill portion (behind the actual progress)
                        Capsule()                                    // NEW
                            .fill(fillColor.opacity(0.3))            // or any "bufferColor"
                            .mask({
                                HStack {
                                    Rectangle()
                                        .frame(
                                            width: max(
                                                bounds.size.width * CGFloat(getPrgPercentage(bufferValue)),
                                                0
                                            ),
                                            alignment: .leading
                                        )
                                    Spacer(minLength: 0)
                                }
                            })
                        
                        // 2) The actual playback progress
                        Capsule()
                            .fill(isActive ? activeFillColor : fillColor)
                            .mask({
                                HStack {
                                    Rectangle()
                                        .frame(
                                            width: max(
                                                bounds.size.width * CGFloat(localRealProgress + localTempProgress),
                                                0
                                            ),
                                            alignment: .leading
                                        )
                                    Spacer(minLength: 0)
                                }
                            })
                    }
                    
                    // Time labels
                    HStack {
                        let shouldShowHours = inRange.upperBound >= 3600
                        Text(value.asTimeString(style: .positional, showHours: shouldShowHours))
                        Spacer(minLength: 0)
                        Text("-" + (inRange.upperBound - value)
                            .asTimeString(style: .positional, showHours: shouldShowHours))
                    }
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? fillColor : emptyColor)
                }
                .frame(width: isActive ? bounds.size.width * 1.04 : bounds.size.width,
                       alignment: .center)
                .animation(animation, value: isActive)
            }
            .frame(width: bounds.size.width, height: bounds.size.height, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($isActive) { _, state, _ in
                        state = true
                    }
                    .onChanged { gesture in
                        localTempProgress = T(gesture.translation.width / bounds.size.width)
                        value = clampValue(getPrgValue())
                    }
                    .onEnded { _ in
                        localRealProgress = getPrgPercentage(value)
                        localTempProgress = 0
                    }
            )
            .onChange(of: isActive) { newValue in
                value = clampValue(getPrgValue())
                onEditingChanged(newValue)
            }
            .onAppear {
                localRealProgress = getPrgPercentage(value)
            }
            .onChange(of: value) { newValue in
                if !isActive {
                    localRealProgress = getPrgPercentage(newValue)
                }
            }
        }
        .frame(height: isActive ? height * 1.25 : height, alignment: .center)
    }
    
    private var animation: Animation {
        isActive
            ? .spring()
            : .spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.6)
    }
    
    private func clampValue(_ val: T) -> T {
        max(min(val, inRange.upperBound), inRange.lowerBound)
    }
    
    private func getPrgPercentage(_ val: T) -> T {
        let clampedValue = clampValue(val)
        let range = inRange.upperBound - inRange.lowerBound
        let pct = (clampedValue - inRange.lowerBound) / range
        return max(min(pct, 1), 0)
    }
    
    private func getPrgValue() -> T {
        ((localRealProgress + localTempProgress) * (inRange.upperBound - inRange.lowerBound))
        + inRange.lowerBound
    }
}
