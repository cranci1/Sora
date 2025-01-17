//
//  Logging.swift
//  Sora
//
//  Created by seiike on 16/01/2025.
//

import Foundation

class Logger {
    static let shared = Logger()
    
    enum LogLevel: String {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    private var logs: [(level: LogLevel, message: String, timestamp: Date)] = []
    private let logFileURL: URL
    
    private init() {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documentDirectory.appendingPathComponent("logs.txt")
        loadLogs()
    }
    
    func log(_ message: String, level: LogLevel = .info) {
        let entry = (level: level, message: message, timestamp: Date())
        logs.append(entry)
        saveLogToFile(entry)
    }
    
    func getLogs() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return logs.map { "[\(dateFormatter.string(from: $0.timestamp))] [\($0.level.rawValue)] \($0.message)" }
            .joined(separator: "\n---\n")
    }
    
    func clearLogs() {
        logs.removeAll()
        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    private func loadLogs() {
        guard let data = try? Data(contentsOf: logFileURL),
              let content = String(data: data, encoding: .utf8) else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        content.components(separatedBy: "\n---\n").forEach { line in
            let components = line.components(separatedBy: "] [")
            guard components.count == 3,
                  let timestampString = components.first?.dropFirst().trimmingCharacters(in: .whitespaces),
                  let timestamp = dateFormatter.date(from: timestampString),
                  let message = components.last?.dropLast() else { return }
            
            let levelRaw = components[1].trimmingCharacters(in: .whitespaces) // No need for guard let
            guard let level = LogLevel(rawValue: levelRaw) else { return }
            
            logs.append((level: level, message: String(message), timestamp: timestamp))
        }
    }
        
        public func saveLogToFile(_ log: (level: LogLevel, message: String, timestamp: Date)) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            let logString = "[\(dateFormatter.string(from: log.timestamp))] [\(log.level.rawValue)] \(log.message)\n---\n"
            
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

