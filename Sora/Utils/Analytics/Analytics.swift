//
//  Analytics.swift
//  Sora
//
//  Created by Hamzo on 28.02.25.
//

import Foundation
import UIKit

struct AnalyticsResponse: Codable {
    let status: String
    let message: String
    let event: String?
    let timestamp: String?
}

@MainActor
class AnalyticsManager {
    static let shared = AnalyticsManager()
    private let analyticsURL = URL(string: "http://151.106.3.14:47474/analytics")!
    private let moduleManager = ModuleManager()
    
    private init() {}
    
    func sendEvent(event: String, additionalData: [String: Any] = [:]) {
        
        let defaults = UserDefaults.standard
        
        if defaults.object(forKey: "analyticsEnabled") == nil {
            defaults.setValue(false, forKey: "analyticsEnabled")
        }
        
        let analyticsEnabled = UserDefaults.standard.bool(forKey: "analyticsEnabled")
        
        guard analyticsEnabled else {
            Logger.shared.log("Analytics is disabled, skipping event: \(event)", type: "Debug")
            return
        }
        
        guard let selectedModule = getSelectedModule() else {
            Logger.shared.log("No selected module found", type: "Debug")
            return
        }
        
        var safeAdditionalData = additionalData
        
        if let errorValue = additionalData["error"] as? NSError {
            safeAdditionalData["error"] = errorValue.localizedDescription
        }
        
        let analyticsData: [String: Any] = [
            "event": event,
            "device": getDeviceModel(),
            "app_version": getAppVersion(),
            "module_name": selectedModule.metadata.sourceName,
            "module_version": selectedModule.metadata.version,
            "data": safeAdditionalData
        ]
        
        sendRequest(with: analyticsData)
    }
    
    private func sendRequest(with data: [String: Any]) {
        var request = URLRequest(url: analyticsURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data, options: [])
        } catch {
            Logger.shared.log("Failed to encode JSON: \(error.localizedDescription)", type: "Debug")
            return
        }
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            if let error = error {
                Logger.shared.log("Request failed: \(error.localizedDescription)", type: "Debug")
                return
            }
            
            guard let data = data else {
                Logger.shared.log("No data received from server", type: "Debug")
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(AnalyticsResponse.self, from: data)
                if decodedResponse.status == "success" {
                    Logger.shared.log("Analytics saved: \(decodedResponse.event ?? "unknown event") at \(decodedResponse.timestamp ?? "unknown time")", type: "Debug")
                } else {
                    Logger.shared.log("Server error: \(decodedResponse.message)", type: "Debug")
                }
            } catch {
                Logger.shared.log("Failed to decode response: \(error.localizedDescription)", type: "Debug")
            }
        }.resume()
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown_version"
    }
    
    private func getDeviceModel() -> String {
        return UIDevice.modelName
    }
    
    private func getSelectedModule() -> ScrapingModule? {
        guard let selectedModuleId = UserDefaults.standard.string(forKey: "selectedModuleId") else { return nil }
        return moduleManager.modules.first { $0.id.uuidString == selectedModuleId }
    }
}
