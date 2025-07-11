//
//  VolumeSlider.swift
//  Custom Seekbar
//
//  Created by Pratik on 08/01/23.
// Credits to Pratik https://github.com/pratikg29/Custom-Slider-Control/blob/main/AppleMusicSlider/AppleMusicSlider/VolumeSlider.swift
//

import SwiftUI

struct VolumeSlider<T: BinaryFloatingPoint>: View {
    @Binding var value: T
    let inRange: ClosedRange<T>
    let activeFillColor: Color
    let fillColor: Color
    let emptyColor: Color
    let height: CGFloat
    let onEditingChanged: (Bool) -> Void

    @State private var localRealProgress: T = 0
    @State private var localTempProgress: T = 0
    @State private var lastVolumeValue: T = 0
    @GestureState private var isActive: Bool = false
    @State private var isAtEnd: Bool = false

    var body: some View {
        GeometryReader { bounds in
            ZStack {
                HStack {
                    GeometryReader { geo in
                        ZStack(alignment: .center) {
                            Capsule().fill(emptyColor)
                            Capsule().fill(isActive ? activeFillColor : fillColor)
                                .mask {
                                    HStack {
                                        Rectangle()
                                            .frame(
                                                width: max(geo.size.width * CGFloat(localRealProgress + localTempProgress), 0),
                                                alignment: .leading
                                            )
                                        Spacer(minLength: 0)
                                    }
                                }
                        }
                    }
                    
                    Image(systemName: getIconName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .frame(width: 30)
                        .foregroundColor(isActive ? activeFillColor : fillColor)
                        .onTapGesture {
                            handleIconTap()
                        }
                }
                .frame(width: getStretchWidth(bounds: bounds), alignment: .center)
                .animation(animation, value: isActive)
                .animation(animation, value: isAtEnd)
            }
            .frame(width: bounds.size.width, height: bounds.size.height)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($isActive) { _, state, _ in state = true }
                    .onChanged { gesture in
                        let delta = gesture.translation.width / bounds.size.width
                        localTempProgress = T(delta)
                        
                        let totalProgress = localRealProgress + localTempProgress
                        if totalProgress <= 0.0 || totalProgress >= 1.0 {
                            isAtEnd = true
                        } else {
                            isAtEnd = false
                        }
                        
                        value = sliderValueInRange()
                    }
                    .onEnded { _ in
                        localRealProgress = max(min(localRealProgress + localTempProgress, 1), 0)
                        localTempProgress = 0
                        isAtEnd = false
                    }
            )
            .onChange(of: isActive) { newValue in
                if !newValue {
                    value = sliderValueInRange()
                    isAtEnd = false
                }
                onEditingChanged(newValue)
            }
            .onAppear {
                localRealProgress = progress(for: value)
                if value > 0 {
                    lastVolumeValue = value
                }
            }
            .onChange(of: value) { newVal in
                if !isActive {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        localRealProgress = progress(for: newVal)
                    }
                    if newVal > 0 {
                        lastVolumeValue = newVal
                    }
                }
            }
        }
        .frame(height: getStretchHeight())
    }

    private var getIconName: String {
        let p = max(0, min(localRealProgress + localTempProgress, 1))
        let muteThreshold: T = 0
        let lowThreshold: T = 0.2
        let midThreshold: T = 0.35
        let highThreshold: T = 0.7
        
        switch p {
        case muteThreshold:
            return "speaker.slash.fill"
        case muteThreshold..<lowThreshold:
            return "speaker.fill"
        case lowThreshold..<midThreshold:
            return "speaker.wave.1.fill"
        case midThreshold..<highThreshold:
            return "speaker.wave.2.fill"
        default:
            return "speaker.wave.3.fill"
        }
    }

    private func handleIconTap() {
        let currentProgress = localRealProgress + localTempProgress
        
        withAnimation {
            if currentProgress <= 0 {
                value = lastVolumeValue
                localRealProgress = progress(for: lastVolumeValue)
                localTempProgress = 0
            } else {
                lastVolumeValue = sliderValueInRange()
                value = T(0)
                localRealProgress = 0
                localTempProgress = 0
            }
        }
    }

    private var animation: Animation {
        .interpolatingSpring(
            mass: 1.0,
            stiffness: 100,
            damping: 15,
            initialVelocity: 0.0
        )
    }

    private func progress(for val: T) -> T {
        let totalRange = inRange.upperBound - inRange.lowerBound
        let adjustedVal = val - inRange.lowerBound
        return adjustedVal / totalRange
    }

    private func sliderValueInRange() -> T {
        let totalProgress = localRealProgress + localTempProgress
        let rawVal = totalProgress * (inRange.upperBound - inRange.lowerBound)
                    + inRange.lowerBound
        return max(min(rawVal, inRange.upperBound), inRange.lowerBound)
    }
    
    private func getStretchWidth(bounds: GeometryProxy) -> CGFloat {
        let baseWidth = bounds.size.width
        if isAtEnd {
            return baseWidth * 1.08 
        } else if isActive {
            return baseWidth * 1.04
        } else {
            return baseWidth
        }
    }
    
    private func getStretchHeight() -> CGFloat {
        if isAtEnd {
            return height * 1.35 
        } else if isActive {
            return height * 1.25 
        } else {
            return height
        }
    }
}
