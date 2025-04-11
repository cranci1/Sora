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
                        .frame(width: 30) // Fixed width keeps layout stable
                        .foregroundColor(isActive ? activeFillColor : fillColor)
                        .onTapGesture {
                            handleIconTap()
                        }
                }
                .frame(width: isActive ? bounds.size.width * 1.02 : bounds.size.width, alignment: .center)
                .animation(animation, value: isActive)
            }
            .frame(width: bounds.size.width, height: bounds.size.height)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($isActive) { _, state, _ in state = true }
                    .onChanged { gesture in
                        let delta = gesture.translation.width / bounds.size.width
                        localTempProgress = T(delta)
                        value = sliderValueInRange()
                    }
                    .onEnded { _ in
                        localRealProgress = max(min(localRealProgress + localTempProgress, 1), 0)
                        localTempProgress = 0
                    }
            )
            .onChange(of: isActive) { newValue in
                if !newValue {
                    value = sliderValueInRange()
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
        .frame(height: isActive ? height * 1.25 : height)
    }

    /// Return an SF Symbols speaker icon that matches 0..1 progress
    private var getIconName: String {
        let p = localRealProgress + localTempProgress
        switch p {
        case 0:
            return "speaker.slash.fill"
        case 0..<0.2:
            return "speaker.fill"
        case 0.2..<0.38:
            return "speaker.wave.1.fill"
        case 0.38..<0.6:
            return "speaker.wave.2.fill"
        default:
            return "speaker.wave.3.fill"
        }
    }

    /// If we tap the icon:
    /// - If volume is 0, restore lastVolumeValue
    /// - Else store the current volume as lastVolumeValue, then set volume=0
    private func handleIconTap() {
        // Current slider progress in [0..1]
        let currentProgress = localRealProgress + localTempProgress
        
        withAnimation {
            if currentProgress <= 0 {
                // We are muted => restore
                value = lastVolumeValue  // e.g. 0.5 => user’s last real volume
                localRealProgress = progress(for: lastVolumeValue)
                localTempProgress = 0
            } else {
                // We are nonzero => store current volume in lastVolumeValue & then mute
                lastVolumeValue = sliderValueInRange()
                value = T(0)
                localRealProgress = 0
                localTempProgress = 0
            }
        }
    }

    /// Returns a spring for the "pressed" expansion
    private var animation: Animation {
        isActive
            ? .spring()
            : .spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.6)
    }

    /// Convert the bound volume => 0..1 progress
    private func progress(for val: T) -> T {
        let totalRange = inRange.upperBound - inRange.lowerBound
        let adjustedVal = val - inRange.lowerBound
        return adjustedVal / totalRange
    }

    /// Convert localRealProgress+localTempProgress => [inRange.lowerBound..inRange.upperBound]
    private func sliderValueInRange() -> T {
        let totalProgress = localRealProgress + localTempProgress
        let rawVal = totalProgress * (inRange.upperBound - inRange.lowerBound)
                    + inRange.lowerBound
        return max(min(rawVal, inRange.upperBound), inRange.lowerBound)
    }
}
