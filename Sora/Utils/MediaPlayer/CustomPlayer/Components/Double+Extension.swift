//
//  Double+Extension.swift
//  AppleMusicSlider
//
//  Created by Pratik on 14/01/23.
//
//  Thanks to pratikg29 for this code inside his open source project "https://github.com/pratikg29/Custom-Slider-Control?ref=iosexample.com"
//

import Foundation
import Combine

extension Double {
    func asTimeString(style: DateComponentsFormatter.UnitsStyle) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = style
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: self) ?? ""
    }
}

extension BinaryFloatingPoint {
    func asTimeString(style: TimeStringStyle, showHours: Bool = false) -> String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if showHours || hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

enum TimeStringStyle {
    case positional
    case standard
}

class VolumeViewModel: ObservableObject {
    @Published var value: Double = 0.0
}

class SliderViewModel: ObservableObject {
    @Published var sliderValue: Double = 0.0
    @Published var introSegments: [ClosedRange<Double>] = []
    @Published var outroSegments: [ClosedRange<Double>] = []
}

struct AniListMediaResponse: Decodable {
  struct DataField: Decodable {
    struct Media: Decodable { let idMal: Int? }
    let Media: Media?
  }
  let data: DataField
}

struct AniSkipResponse: Decodable {
  struct Result: Decodable {
    struct Interval: Decodable {
      let startTime: Double
      let endTime:   Double
    }
    let interval: Interval
    let skipType: String
  }
  let found:      Bool
  let results:    [Result]
  let statusCode: Int
}
