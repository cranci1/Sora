//
//  Logging.swift
//  Sora
//
//  Created by seiike on 16/01/2025.
//

import SwiftUI
import Combine
import Foundation

class LogManager: ObservableObject {
    static let shared = LogManager()

    @Published var logs: [String] = []
    private let logFileURL: URL

    private init() {
        // Setup the log file
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documentDirectory.appendingPathComponent("logs.txt")
        
        // Load existing logs from the file
        loadLogs()
    }

    func addLog(_ log: String) {
        let timestamp = Date().formatted()
        let logEntry = "[\(timestamp)] \(log)"
        logs.append(logEntry)

        // Save to file
        saveLogToFile(logEntry)
    }

    private func loadLogs() {
        if let logData = try? Data(contentsOf: logFileURL),
           let logContent = String(data: logData, encoding: .utf8) {
            logs = logContent.components(separatedBy: "\n").filter { !$0.isEmpty }
        }
    }

    private func saveLogToFile(_ log: String) {
        let logWithNewline = log + "\n"
        if let data = logWithNewline.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let handle = try? FileHandle(forWritingTo: logFileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }

    func clearLogs() {
        logs.removeAll()
        try? FileManager.default.removeItem(at: logFileURL)
    }
}

// Override `print`
func print(_ items: Any...) {
    let output = items.map { "\($0)" }.joined(separator: " ")
    LogManager.shared.addLog(output)
    Swift.print(output) // Still send output to the console for debugging
}
