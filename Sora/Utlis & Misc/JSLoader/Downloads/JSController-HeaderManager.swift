//
//  JSController-HeaderManager.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import Foundation

// Protocol for header management functionality
protocol HeaderManaging {
    func logHeadersForRequest(headers: [String: String], url: URL, operation: String)
    func ensureStreamingHeaders(headers: [String: String], for url: URL) -> [String: String]
    func combineStreamingHeaders(originalHeaders: [String: String], streamHeaders: [String: String], for url: URL) -> [String: String]
}

// Extension for managing HTTP headers in the JSController
extension JSController: HeaderManaging {
    
    // Enable verbose logging for development/testing
    static var verboseHeaderLogging: Bool = true
    
    /// Standard headers needed for most streaming sites
    struct StandardHeaders {
        // Common header keys
        static let origin = "Origin"
        static let referer = "Referer"
        static let userAgent = "User-Agent"
        
        // Default user agent for streaming
        static let defaultUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"
    }
    
    /// Logs messages with a consistent format if verbose logging is enabled
    /// - Parameters:
    ///   - message: The message to log
    ///   - function: The calling function (auto-filled)
    ///   - line: The line number (auto-filled)
    private func logHeader(_ message: String, function: String = #function, line: Int = #line) {
        if JSController.verboseHeaderLogging {
            print("[HeaderManager:\(function):\(line)] \(message)")
        }
    }
    
    /// Ensures that the necessary headers for streaming are present
    /// - Parameters:
    ///   - headers: Original headers from the request
    ///   - url: The URL being requested
    /// - Returns: Headers with necessary streaming headers added if missing
    func ensureStreamingHeaders(headers: [String: String], for url: URL) -> [String: String] {
        logHeader("Ensuring streaming headers for URL: \(url.absoluteString)")
        logHeader("Original headers count: \(headers.count)")
        
        var updatedHeaders = headers
        
        // Check if we have a URL host
        guard let host = url.host else {
            logHeader("No host in URL, returning original headers")
            return headers
        }
        
        // Generate base URL (scheme + host)
        let baseUrl = "\(url.scheme ?? "https")://\(host)"
        logHeader("Base URL for headers: \(baseUrl)")
        
        // Ensure Origin is set
        if updatedHeaders[StandardHeaders.origin] == nil {
            logHeader("Adding missing Origin header: \(baseUrl)")
            updatedHeaders[StandardHeaders.origin] = baseUrl
        }
        
        // Ensure Referer is set
        if updatedHeaders[StandardHeaders.referer] == nil {
            logHeader("Adding missing Referer header: \(baseUrl)")
            updatedHeaders[StandardHeaders.referer] = baseUrl
        }
        
        // Ensure User-Agent is set
        if updatedHeaders[StandardHeaders.userAgent] == nil {
            logHeader("Adding missing User-Agent header")
            updatedHeaders[StandardHeaders.userAgent] = StandardHeaders.defaultUserAgent
        }
        
        // Add additional common streaming headers that might help with 403 errors
        let additionalHeaders: [String: String] = [
            "Accept": "*/*",
            "Accept-Language": "en-US,en;q=0.9",
            "Sec-Fetch-Dest": "empty",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Site": "same-origin"
        ]
        
        for (key, value) in additionalHeaders {
            if updatedHeaders[key] == nil {
                updatedHeaders[key] = value
            }
        }
        
        logHeader("Final headers count: \(updatedHeaders.count)")
        return updatedHeaders
    }
    
    /// Preserves critical headers from the original stream while adding new ones
    /// - Parameters:
    ///   - originalHeaders: Original headers used for fetching the master playlist
    ///   - streamHeaders: Headers for the specific stream (may be empty)
    ///   - url: The URL of the stream
    /// - Returns: Combined headers optimized for the stream request
    func combineStreamingHeaders(originalHeaders: [String: String], streamHeaders: [String: String], for url: URL) -> [String: String] {
        logHeader("Combining headers for URL: \(url.absoluteString)")
        logHeader("Original headers count: \(originalHeaders.count), Stream headers count: \(streamHeaders.count)")
        
        var combinedHeaders: [String: String] = [:]
        
        // Add all stream-specific headers first (highest priority)
        for (key, value) in streamHeaders {
            combinedHeaders[key] = value
        }
        
        // Add original headers for any keys not already present
        for (key, value) in originalHeaders {
            if combinedHeaders[key] == nil {
                combinedHeaders[key] = value
            }
        }
        
        logHeader("Combined headers count before ensuring: \(combinedHeaders.count)")
        
        // Finally, ensure all critical headers are present
        let finalHeaders = ensureStreamingHeaders(headers: combinedHeaders, for: url)
        
        return finalHeaders
    }
    
    /// Logs the headers being used for a request (for debugging)
    /// - Parameters:
    ///   - headers: The headers to log
    ///   - url: The URL being requested
    ///   - operation: The operation being performed (e.g., "Downloading", "Extracting")
    func logHeadersForRequest(headers: [String: String], url: URL, operation: String) {
        logHeader("\(operation) \(url.absoluteString)")
        logHeader("Headers:")
        
        // Get the important headers first
        let importantKeys = [
            StandardHeaders.origin,
            StandardHeaders.referer,
            StandardHeaders.userAgent
        ]
        
        for key in importantKeys {
            if let value = headers[key] {
                logHeader("   [IMPORTANT] \(key): \(value)")
            } else {
                logHeader("   [MISSING] \(key)")
            }
        }
        
        // Then log all other headers
        for (key, value) in headers {
            if !importantKeys.contains(key) {
                logHeader("   \(key): \(value)")
            }
        }
    }
} 