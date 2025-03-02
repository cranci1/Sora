//
//  Logging.swift
//  Sora
//
//  Created by seiike on 16/01/2025.
//

import Foundation

class Logger {
    static let shared = Logger()
    
    struct LogEntry {
        let message: String
        let type: String
        let timestamp: Date
    }
    
    private var logs: [LogEntry] = []
    private let logFileURL: URL
    private let logFilterViewModel = LogFilterViewModel.shared
    
    private init() {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documentDirectory.appendingPathComponent("logs.txt")
    }
    
    func log(_ message: String, type: String = "General") {
        guard logFilterViewModel.isFilterEnabled(for: type) else { return }
        
        let entry = LogEntry(message: message, type: type, timestamp: Date())
        logs.append(entry)
        saveLogToFile(entry)
        
        // Print to Xcode console
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM HH:mm:ss"
        let formattedMessage = "[\(dateFormatter.string(from: entry.timestamp))] [\(entry.type)] \(entry.message)"
        
        //print(formattedMessage) // TODO: Remove this line in production, DEBUG only
    }
    
    func getLogs() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM HH:mm:ss"
        return logs.map { "[\(dateFormatter.string(from: $0.timestamp))] [\($0.type)] \($0.message)" }
        .joined(separator: "\n----\n")
    }
    
    func clearLogs() {
        logs.removeAll()
        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    private func saveLogToFile(_ log: LogEntry) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM HH:mm:ss"
        
        let logString = "[\(dateFormatter.string(from: log.timestamp))] [\(log.type)] \(log.message)\n---\n"
        
        if let data = logString.data(using: .utf8) {
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
}
