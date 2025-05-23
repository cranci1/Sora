//
//  M3U8StreamExtractor.swift
//  Sora
//
//  Created by Francesco on 30/04/25.
//

import Foundation

enum M3U8StreamExtractorError: Error {
    case networkError(Error)
    case parsingError(String)
    case noStreamFound
    case invalidURL
    
    var localizedDescription: String {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        case .noStreamFound:
            return "No suitable stream found in playlist"
        case .invalidURL:
            return "Invalid stream URL"
        }
    }
}

class M3U8StreamExtractor {
    
    // Enable verbose logging for development/testing
    static var verboseLogging: Bool = true
    
    /// Logs messages with a consistent format if verbose logging is enabled
    /// - Parameters:
    ///   - message: The message to log
    ///   - function: The calling function (auto-filled)
    ///   - line: The line number (auto-filled)
    private static func log(_ message: String, function: String = #function, line: Int = #line) {
        if verboseLogging {
            print("[M3U8Extractor:\(function):\(line)] \(message)")
        }
    }
    
    /// Extracts the appropriate stream URL from a master M3U8 playlist based on quality preference
    /// - Parameters:
    ///   - masterURL: The URL of the master M3U8 playlist
    ///   - headers: HTTP headers to use for the request
    ///   - preferredQuality: User's preferred quality ("Best", "High", "Medium", "Low")
    ///   - jsController: Optional reference to the JSController for header management
    ///   - completion: Completion handler with the result containing the selected stream URL and headers
    static func extractStreamURL(
        from masterURL: URL,
        headers: [String: String],
        preferredQuality: String,
        jsController: JSController? = nil,
        completion: @escaping (Result<(streamURL: URL, headers: [String: String]), Error>) -> Void
    ) {
        log("Starting extraction from master playlist: \(masterURL.absoluteString)")
        log("Preferred quality: \(preferredQuality)")
        
        var requestHeaders = headers
        
        // Use header manager if available
        if let controller = jsController {
            log("Using JSController for header management")
            requestHeaders = controller.ensureStreamingHeaders(headers: headers, for: masterURL)
            controller.logHeadersForRequest(headers: requestHeaders, url: masterURL, operation: "Extracting streams from")
        } else {
            log("JSController not provided, using original headers")
        }
        
        var request = URLRequest(url: masterURL)
        
        // Add headers to the request
        for (key, value) in requestHeaders {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Add a unique request ID for tracking in logs
        let requestID = UUID().uuidString.prefix(8)
        log("Request ID: \(requestID)")
        
        // Fetch the master playlist
        log("Sending request to fetch master playlist")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle network errors
            if let error = error {
                log("Network error: \(error.localizedDescription)")
                completion(.failure(M3U8StreamExtractorError.networkError(error)))
                return
            }
            
            // Log HTTP status for debugging
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                log("HTTP Status: \(statusCode) for \(masterURL.absoluteString)")
                
                if statusCode == 403 {
                    log("HTTP Error 403: Access Forbidden")
                    
                    // Try to extract domain from URL for logging
                    let domain = masterURL.host ?? "unknown domain"
                    log("Access denied by server: \(domain)")
                    
                    // Check if we have essential headers that might be missing/incorrect
                    let missingCriticalHeaders = ["Origin", "Referer", "User-Agent"].filter { requestHeaders[$0] == nil }
                    if !missingCriticalHeaders.isEmpty {
                        log("Missing critical headers: \(missingCriticalHeaders.joined(separator: ", "))")
                    }
                    
                    // Since we got a 403, just fall back to the master URL directly
                    log("403 error - Falling back to master URL")
                    completion(.success((streamURL: masterURL, headers: requestHeaders)))
                    return
                } else if statusCode >= 400 {
                    log("HTTP Error: \(statusCode)")
                    completion(.failure(M3U8StreamExtractorError.parsingError("HTTP Error: \(statusCode)")))
                    return
                }
                
                // Log response headers for debugging
                log("Response Headers:")
                for (key, value) in httpResponse.allHeaderFields {
                    log("   \(key): \(value)")
                }
            }
            
            // Ensure we have data
            guard let data = data else {
                log("No data received")
                completion(.failure(M3U8StreamExtractorError.parsingError("No data received")))
                return
            }
            
            // Try to parse as string
            guard let content = String(data: data, encoding: .utf8) else {
                log("Failed to decode playlist content")
                completion(.failure(M3U8StreamExtractorError.parsingError("Failed to decode playlist content")))
                return
            }
            
            // Log a sample of the content (first 200 chars)
            let contentPreview = String(content.prefix(200))
            log("Playlist Content (preview): \(contentPreview)...")
            
            // Count the number of lines in the content
            let lineCount = content.components(separatedBy: .newlines).count
            log("Playlist has \(lineCount) lines")
            
            // Parse the M3U8 content to extract available streams
            log("Parsing M3U8 content")
            let streams = parseM3U8Content(content: content, baseURL: masterURL)
            
            // Log the extracted streams
            log("Extracted \(streams.count) streams from M3U8 playlist")
            for (index, stream) in streams.enumerated() {
                log("Stream #\(index + 1): \(stream.name), \(stream.resolution.width)x\(stream.resolution.height), URL: \(stream.url)")
            }
            
            if streams.isEmpty {
                log("No streams found in playlist")
            }
            
            // Select the appropriate stream based on quality preference
            log("Selecting stream with quality preference: \(preferredQuality)")
            if let selectedURL = selectStream(streams: streams, preferredQuality: preferredQuality),
               let url = URL(string: selectedURL) {
                
                log("Selected stream URL: \(url.absoluteString)")
                
                var finalHeaders = requestHeaders
                
                // Use header manager to optimize headers for the selected stream if available
                if let controller = jsController {
                    log("Optimizing headers for selected stream")
                    finalHeaders = controller.ensureStreamingHeaders(headers: requestHeaders, for: url)
                    controller.logHeadersForRequest(headers: finalHeaders, url: url, operation: "Selected stream")
                }
                
                // Return the selected stream URL along with the headers
                log("Extraction successful")
                completion(.success((streamURL: url, headers: finalHeaders)))
            } else if !streams.isEmpty, let fallbackStream = streams.first, let url = URL(string: fallbackStream.url) {
                // Fallback to first stream if preferred quality not found
                log("Preferred quality '\(preferredQuality)' not found, falling back to: \(fallbackStream.name)")
                
                var finalHeaders = requestHeaders
                
                // Use header manager for fallback stream
                if let controller = jsController {
                    log("Optimizing headers for fallback stream")
                    finalHeaders = controller.ensureStreamingHeaders(headers: requestHeaders, for: url)
                    controller.logHeadersForRequest(headers: finalHeaders, url: url, operation: "Fallback stream")
                }
                
                log("Fallback extraction successful")
                completion(.success((streamURL: url, headers: finalHeaders)))
            } else if streams.isEmpty {
                // If the playlist doesn't contain any streams, use the master URL as fallback
                log("No streams found in the playlist, using master URL as fallback")
                log("Using master URL as fallback")
                completion(.success((streamURL: masterURL, headers: requestHeaders)))
            } else {
                log("No suitable stream found")
                completion(.failure(M3U8StreamExtractorError.noStreamFound))
            }
        }
        
        task.resume()
        log("Request started")
    }
    
    /// Parses M3U8 content to extract available streams
    /// - Parameters:
    ///   - content: The M3U8 playlist content as string
    ///   - baseURL: The base URL of the playlist for resolving relative URLs
    /// - Returns: Array of extracted streams with name, URL, and resolution
    private static func parseM3U8Content(
        content: String,
        baseURL: URL
    ) -> [(name: String, url: String, resolution: (width: Int, height: Int))] {
        let lines = content.components(separatedBy: .newlines)
        var streams: [(name: String, url: String, resolution: (width: Int, height: Int))] = []
        
        for (index, line) in lines.enumerated() {
            // Look for the stream info tag
            if line.contains("#EXT-X-STREAM-INF"), index + 1 < lines.count {
                // Extract resolution information
                if let resolutionRange = line.range(of: "RESOLUTION="),
                   let resolutionEndRange = line[resolutionRange.upperBound...].range(of: ",") 
                    ?? line[resolutionRange.upperBound...].range(of: "\n") {
                    
                    let resolutionPart = String(line[resolutionRange.upperBound..<resolutionEndRange.lowerBound])
                    let dimensions = resolutionPart.components(separatedBy: "x")
                    
                    if dimensions.count == 2,
                       let width = Int(dimensions[0]),
                       let height = Int(dimensions[1]) {
                        
                        // Get the URL from the next line
                        let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Generate a quality name
                        let qualityName = getQualityName(for: height)
                        
                        // Handle relative URLs
                        var streamURL = nextLine
                        if !nextLine.hasPrefix("http") && nextLine.contains(".m3u8") {
                            let baseURLString = baseURL.deletingLastPathComponent().absoluteString
                            streamURL = URL(string: nextLine, relativeTo: baseURL)?.absoluteString
                                ?? baseURLString + "/" + nextLine
                        }
                        
                        // Add the stream to our list
                        streams.append((
                            name: qualityName,
                            url: streamURL,
                            resolution: (width: width, height: height)
                        ))
                    }
                }
            }
        }
        
        return streams
    }
    
    /// Selects a stream based on the user's quality preference
    /// - Parameters:
    ///   - streams: Array of available streams
    ///   - preferredQuality: User's preferred quality
    /// - Returns: URL of the selected stream, or nil if no suitable stream was found
    private static func selectStream(
        streams: [(name: String, url: String, resolution: (width: Int, height: Int))],
        preferredQuality: String
    ) -> String? {
        guard !streams.isEmpty else { return nil }
        
        // Sort streams by resolution (height) in descending order
        let sortedStreams = streams.sorted { $0.resolution.height > $1.resolution.height }
        
        switch preferredQuality {
        case "Best":
            // Return the highest quality stream
            return sortedStreams.first?.url
            
        case "High":
            // Return a high quality stream (720p or higher, but not the highest)
            let highStreams = sortedStreams.filter { $0.resolution.height >= 720 }
            if highStreams.count > 1 {
                return highStreams[1].url  // Second highest if available
            } else if !highStreams.isEmpty {
                return highStreams[0].url  // Highest if only one high quality stream
            } else if !sortedStreams.isEmpty {
                return sortedStreams.first?.url  // Fallback to highest available
            }
            
        case "Medium":
            // Return a medium quality stream (between 480p and 720p)
            let mediumStreams = sortedStreams.filter { 
                $0.resolution.height >= 480 && $0.resolution.height < 720 
            }
            if !mediumStreams.isEmpty {
                return mediumStreams.first?.url
            } else if sortedStreams.count > 1 {
                let medianIndex = sortedStreams.count / 2
                return sortedStreams[medianIndex].url  // Return median quality as fallback
            } else if !sortedStreams.isEmpty {
                return sortedStreams.first?.url  // Fallback to highest available
            }
            
        case "Low":
            // Return the lowest quality stream
            return sortedStreams.last?.url
            
        default:
            // Default to best quality
            return sortedStreams.first?.url
        }
        
        return nil
    }
    
    /// Generates a quality name based on resolution height
    /// - Parameter height: The vertical resolution (height) of the stream
    /// - Returns: A human-readable quality name
    private static func getQualityName(for height: Int) -> String {
        switch height {
        case 1080...: return "\(height)p (FHD)"
        case 720..<1080: return "\(height)p (HD)"
        case 480..<720: return "\(height)p (SD)"
        default: return "\(height)p"
        }
    }
} 