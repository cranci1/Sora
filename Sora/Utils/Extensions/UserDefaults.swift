//
//  UserDefaults.swift
//  Sulfur
//
//  Created by Francesco on 23/05/25.
//

import UIKit

enum VideoQualityPreference: String, CaseIterable {
    case best = "Best"
    case p1080 = "1080p"
    case p720 = "720p"
    case p420 = "420p"
    case p360 = "360p"
    case worst = "Worst"
    
    static let wifiDefaultKey = "videoQualityWiFi"
    static let cellularDefaultKey = "videoQualityCellular"
    
    static let defaultWiFiPreference: VideoQualityPreference = .best
    static let defaultCellularPreference: VideoQualityPreference = .p720
    
    static let qualityPriority: [VideoQualityPreference] = [.best, .p1080, .p720, .p420, .p360, .worst]
    
    static func findClosestQuality(preferred: VideoQualityPreference, availableQualities: [(String, String)]) -> (String, String)? {
        for (name, url) in availableQualities {
            if isQualityMatch(preferred: preferred, qualityName: name) {
                return (name, url)
            }
        }
        
        let preferredIndex = qualityPriority.firstIndex(of: preferred) ?? qualityPriority.count
        
        for i in 0..<qualityPriority.count {
            let candidate = qualityPriority[i]
            for (name, url) in availableQualities {
                if isQualityMatch(preferred: candidate, qualityName: name) {
                    return (name, url)
                }
            }
        }
        
        return availableQualities.first
    }
    
    private static func isQualityMatch(preferred: VideoQualityPreference, qualityName: String) -> Bool {
        let lowercaseName = qualityName.lowercased()
        
        switch preferred {
        case .best:
            return lowercaseName.contains("best") || lowercaseName.contains("highest") || lowercaseName.contains("max")
        case .p1080:
            return lowercaseName.contains("1080") || lowercaseName.contains("1920")
        case .p720:
            return lowercaseName.contains("720") || lowercaseName.contains("1280")
        case .p420:
            return lowercaseName.contains("420") || lowercaseName.contains("480")
        case .p360:
            return lowercaseName.contains("360") || lowercaseName.contains("640")
        case .worst:
            return lowercaseName.contains("worst") || lowercaseName.contains("lowest") || lowercaseName.contains("min")
        }
    }
}

extension UserDefaults {
    func color(forKey key: String) -> UIColor? {
        guard let colorData = data(forKey: key) else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData)
        } catch {
            return nil
        }
    }
    
    func set(_ color: UIColor?, forKey key: String) {
        guard let color = color else {
            removeObject(forKey: key)
            return
        }
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
            set(data, forKey: key)
        } catch {
            Logger.shared.log("Error archiving color: \(error)", type: "Error")
        }
    }
    
    static func getVideoQualityPreference() -> VideoQualityPreference {
        let networkType = NetworkMonitor.getCurrentNetworkType()
        
        switch networkType {
        case .wifi:
            let rawValue = UserDefaults.standard.string(forKey: VideoQualityPreference.wifiDefaultKey)
            return VideoQualityPreference(rawValue: rawValue ?? "") ?? VideoQualityPreference.defaultWiFiPreference
        case .cellular:
            let rawValue = UserDefaults.standard.string(forKey: VideoQualityPreference.cellularDefaultKey)
            return VideoQualityPreference(rawValue: rawValue ?? "") ?? VideoQualityPreference.defaultCellularPreference
        case .unknown:
            return .p720
        }
    }
}
