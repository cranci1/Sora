//
//  Analytics.swift
//  Sora
//
//  Created by Hamzo on 28.02.25.
//

import Foundation
import UIKit

// MARK: - Analytics Response Model
struct AnalyticsResponse: Codable {
    let status: String
    let message: String
    let event: String?
    let timestamp: String?
}

// MARK: - Analytics Manager
class AnalyticsManager {
    static let shared = AnalyticsManager()
    private let analyticsURL = URL(string: "http://151.106.3.14:47474/analytics")!
    private let moduleManager = ModuleManager()

    private init() {
        Logger.shared.log("Analytics initializer called", type: .info)
    }

    // MARK: - Send Analytics Data
    func sendEvent(event: String, additionalData: [String: Any] = [:]) {
        let defaults = UserDefaults.standard

        // Ensure the key is set with a default value if missing
        if defaults.object(forKey: "analyticsEnabled") == nil {
            defaults.setValue(false, forKey: "analyticsEnabled")
        }

        let analyticsEnabled = UserDefaults.standard.bool(forKey: "analyticsEnabled")

        guard analyticsEnabled else {
            Logger.shared.log("Analytics is disabled, skipping event: \(event)", type: .debug)
            return
        }

        guard let selectedModule = getSelectedModule() else {
            Logger.shared.log("No selected module found", type: .debug)
            return
        }

        // Prepare analytics data
        var safeAdditionalData = additionalData

        // Check and convert NSError if present
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

    // MARK: - Private Request Method
    private func sendRequest(with data: [String: Any]) {
        var request = URLRequest(url: analyticsURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data, options: [])
        } catch {
            Logger.shared.log("Failed to encode JSON: \(error.localizedDescription)", type: .debug)
            return
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                Logger.shared.log("Request failed: \(error.localizedDescription)", type: .debug)
                return
            }

            guard let data else {
                Logger.shared.log("No data received from server", type: .debug)
                return
            }

            do {
                let decodedResponse = try JSONDecoder().decode(AnalyticsResponse.self, from: data)
                if decodedResponse.status == "success" {
                    Logger.shared.log("Analytics saved: \(decodedResponse.event ?? "unknown event") at \(decodedResponse.timestamp ?? "unknown time")", type: .debug)
                } else {
                    Logger.shared.log("Server error: \(decodedResponse.message)", type: .debug)
                }
            } catch {
                Logger.shared.log("Failed to decode response: \(error.localizedDescription)", type: .debug)
            }
        }.resume()
    }

    // MARK: - Get App Version
    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown_version"
    }

    // MARK: - Get Device Model
    private func getDeviceModel() -> String {
        UIDevice.modelName
    }

    // MARK: - Get Selected Module
    private func getSelectedModule() -> ScrapingModule? {
        guard let selectedModuleId = UserDefaults.standard.string(forKey: "selectedModuleId") else { return nil }
        return moduleManager.modules.first { $0.id.uuidString == selectedModuleId }
    }
}
