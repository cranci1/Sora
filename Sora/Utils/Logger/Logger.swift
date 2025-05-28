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
    
    private let queue = DispatchQueue(label: "me.cranci.sora.logger", attributes: .concurrent)
    private var logs: [LogEntry] = []
    private let logFileURL: URL
    private let logFilterViewModel = LogFilterViewModel.shared
    
    private let maxFileSize = 1024 * 512
    
    private init() {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documentDirectory.appendingPathComponent("logs.txt")
    }
    
    func log(_ message: String, type: String = "General") {
        guard logFilterViewModel.isFilterEnabled(for: type) else { return }
        
        let entry = LogEntry(message: message, type: type, timestamp: Date())
        
        queue.async(flags: .barrier) {
            self.logs.append(entry)
            self.saveLogToFile(entry)
            self.debugLog(entry)
        }
    }
    
    func getLogs() -> String {
        var result = ""
        queue.sync {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd-MM HH:mm:ss"
            result = logs.map { "[\(dateFormatter.string(from: $0.timestamp))] [\($0.type)] \($0.message)" }
            .joined(separator: "\n----\n")
        }
        return result
    }
    
    func clearLogs() {
        queue.async(flags: .barrier) {
            self.logs.removeAll()
            try? FileManager.default.removeItem(at: self.logFileURL)
        }
    }
    
    private func saveLogToFile(_ log: LogEntry) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM HH:mm:ss"
        
        let logString = "[\(dateFormatter.string(from: log.timestamp))] [\(log.type)] \(log.message)\n---\n"
        
        guard let data = logString.data(using: .utf8) else {
            print("Failed to encode log string to UTF-8")
            return
        }
        
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: logFileURL.path)
                let fileSize = attributes[.size] as? UInt64 ?? 0
                
                if fileSize + UInt64(data.count) > maxFileSize {
                    guard var content = try? String(contentsOf: logFileURL, encoding: .utf8) else { return }
                    
                    // Ensure content is not empty and contains valid UTF-8
                    guard !content.isEmpty else {
                        try? data.write(to: logFileURL)
                        return
                    }
                    
                    // Remove old entries until we have space
                    while (content.data(using: .utf8)?.count ?? 0) + data.count > maxFileSize {
                        if let rangeOfFirstLine = content.range(of: "\n---\n") {
                            // Ensure we don't try to remove beyond the string's bounds
                            let endIndex = min(rangeOfFirstLine.upperBound, content.endIndex)
                            content.removeSubrange(content.startIndex..<endIndex)
                        } else {
                            // If we can't find a separator, clear the content
                            content = ""
                            break
                        }
                        
                        // Safety check to prevent infinite loops
                        if content.isEmpty {
                            break
                        }
                    }
                    
                    // Append new log entry
                    content += logString
                    
                    // Write back to file
                    if let finalData = content.data(using: .utf8) {
                        try? finalData.write(to: logFileURL)
                    }
                } else {
                    if let handle = try? FileHandle(forWritingTo: logFileURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                }
            } catch {
                print("Error managing log file: \(error)")
            }
        } else {
            try? data.write(to: logFileURL)
        }
    }
    
    /// Prints log messages to the Xcode console only in DEBUG mode
    private func debugLog(_ entry: LogEntry) {
#if DEBUG
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM HH:mm:ss"
        let formattedMessage = "[\(dateFormatter.string(from: entry.timestamp))] [\(entry.type)] \(entry.message)"
        print(formattedMessage)
#endif
    }
}
