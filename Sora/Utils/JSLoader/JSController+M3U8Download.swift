//
//  JSController+M3U8Download.swift
//  Sora
//
//  Created by Francesco on 30/04/25.
//

import Foundation
import SwiftUI

// No need to import DownloadQualityPreference as it's in the same module

// Extension for integrating M3U8StreamExtractor with JSController for downloads
extension JSController {
    
    /// Initiates a download for a given URL, handling M3U8 playlists if necessary
    /// - Parameters:
    ///   - url: The URL to download
    ///   - headers: HTTP headers to use for the request
    ///   - title: Title for the download (optional)
    ///   - completionHandler: Called when the download is initiated or fails
    func downloadWithM3U8Support(url: URL, headers: [String: String], title: String? = nil, completionHandler: ((Bool, String) -> Void)? = nil) {
        // Use headers passed in from caller rather than generating our own baseUrl
        // Receiving code should already be setting module.metadata.baseUrl
        
        print("Starting download process for URL: \(url.absoluteString)")
        print("Using headers: \(headers)")
        
        // Check if the URL is an M3U8 file
        if url.absoluteString.contains(".m3u8") {
            // Get the user's quality preference
            let preferredQuality = DownloadQualityPreference.current.rawValue
            
            print("Starting M3U8 download with quality preference: \(preferredQuality)")
            
            // Parse the M3U8 content to extract available qualities, matching CustomPlayer approach
            parseM3U8(url: url, baseUrl: url.absoluteString, headers: headers) { [weak self] qualities in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if qualities.isEmpty {
                        print("No quality options found in M3U8, downloading the original URL")
                        self.downloadWithOriginalMethod(
                            url: url,
                            headers: headers,
                            title: title,
                            completionHandler: completionHandler
                        )
                        return
                    }
                    
                    print("Found \(qualities.count) quality options in M3U8")
                    
                    // Select appropriate quality based on user preference
                    let selectedQuality = self.selectQualityBasedOnPreference(qualities: qualities, preferredQuality: preferredQuality)
                    
                    if let qualityURL = URL(string: selectedQuality.1) {
                        print("Selected quality: \(selectedQuality.0) at URL: \(qualityURL.absoluteString)")
                        
                        // Download with standard headers that match the player
                        self.downloadWithOriginalMethod(
                            url: qualityURL,
                            headers: headers,
                            title: title,
                            completionHandler: completionHandler
                        )
                    } else {
                        print("Invalid quality URL, falling back to original URL")
                        self.downloadWithOriginalMethod(
                            url: url,
                            headers: headers,
                            title: title,
                            completionHandler: completionHandler
                        )
                    }
                }
            }
        } else {
            // Not an M3U8 file, use the original download method with standard headers
            downloadWithOriginalMethod(
                url: url,
                headers: headers,
                title: title,
                completionHandler: completionHandler
            )
        }
    }
    
    /// Parses an M3U8 file to extract available quality options, matching CustomPlayer's approach exactly
    /// - Parameters:
    ///   - url: The URL of the M3U8 file
    ///   - baseUrl: The base URL for setting headers
    ///   - headers: HTTP headers to use for the request
    ///   - completion: Called with the array of quality options (name, URL)
    private func parseM3U8(url: URL, baseUrl: String, headers: [String: String], completion: @escaping ([(String, String)]) -> Void) {
        var request = URLRequest(url: url)
        
        // Add headers from headers passed to downloadWithM3U8Support
        // This ensures we use the same headers as the player (from module.metadata.baseUrl)
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        print("Fetching M3U8 content from: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Log HTTP status for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status: \(httpResponse.statusCode) for \(url.absoluteString)")
                
                if httpResponse.statusCode >= 400 {
                    print("HTTP Error: \(httpResponse.statusCode)")
                    completion([])
                    return
                }
            }
            
            guard let data = data, let content = String(data: data, encoding: .utf8) else {
                print("Failed to load or decode M3U8 file")
                completion([])
                return
            }
            
            let lines = content.components(separatedBy: .newlines)
            var qualities: [(String, String)] = []
            
            // Always include the original URL as "Auto" option
            qualities.append(("Auto (Recommended)", url.absoluteString))
            
            func getQualityName(for height: Int) -> String {
                switch height {
                case 1080...: return "\(height)p (FHD)"
                case 720..<1080: return "\(height)p (HD)"
                case 480..<720: return "\(height)p (SD)"
                default: return "\(height)p"
                }
            }
            
            // Parse the M3U8 content to extract available streams - exactly like CustomPlayer
            for (index, line) in lines.enumerated() {
                if line.contains("#EXT-X-STREAM-INF"), index + 1 < lines.count {
                    if let resolutionRange = line.range(of: "RESOLUTION="),
                       let resolutionEndRange = line[resolutionRange.upperBound...].range(of: ",")
                        ?? line[resolutionRange.upperBound...].range(of: "\n") {
                        
                        let resolutionPart = String(line[resolutionRange.upperBound..<resolutionEndRange.lowerBound])
                        if let heightStr = resolutionPart.components(separatedBy: "x").last,
                           let height = Int(heightStr) {
                            
                            let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                            let qualityName = getQualityName(for: height)
                            
                            var qualityURL = nextLine
                            if !nextLine.hasPrefix("http") && nextLine.contains(".m3u8") {
                                // Handle relative URLs
                                let baseURLString = url.deletingLastPathComponent().absoluteString
                                qualityURL = URL(string: nextLine, relativeTo: url)?.absoluteString
                                    ?? baseURLString + "/" + nextLine
                            }
                            
                            if !qualities.contains(where: { $0.0 == qualityName }) {
                                qualities.append((qualityName, qualityURL))
                            }
                        }
                    }
                }
            }
            
            // Sort qualities like CustomPlayer does - on the main thread
            let autoQuality = qualities.first
            var sortedQualities = qualities.dropFirst().sorted { first, second in
                let firstHeight = Int(first.0.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
                let secondHeight = Int(second.0.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
                return firstHeight > secondHeight
            }
            
            if let auto = autoQuality {
                sortedQualities.insert(auto, at: 0)
            }
            
            print("Extracted \(sortedQualities.count) quality options from M3U8")
            completion(sortedQualities)
        }.resume()
    }
    
    /// Selects the appropriate quality based on user preference
    /// - Parameters:
    ///   - qualities: Available quality options (name, URL)
    ///   - preferredQuality: User's preferred quality
    /// - Returns: The selected quality (name, URL)
    private func selectQualityBasedOnPreference(qualities: [(String, String)], preferredQuality: String) -> (String, String) {
        // If only one quality is available, return it
        if qualities.count <= 1 {
            return qualities[0]
        }
        
        // Select quality based on preference
        switch preferredQuality {
        case "Best":
            // Skip the "Auto" option which is at index 0
            return qualities.count > 1 ? qualities[1] : qualities[0]
            
        case "High":
            // Look for 720p quality
            let highQuality = qualities.first {
                $0.0.contains("720p") || $0.0.contains("HD")
            }
            return highQuality ?? (qualities.count > 1 ? qualities[1] : qualities[0])
            
        case "Medium":
            // Look for 480p quality
            let mediumQuality = qualities.first {
                $0.0.contains("480p") || $0.0.contains("SD")
            }
            
            if let medium = mediumQuality {
                return medium
            } else if qualities.count > 2 {
                // Return middle quality if no exact match
                return qualities[qualities.count / 2]
            } else {
                // Last quality or Auto if nothing else
                return qualities.last ?? qualities[0]
            }
            
        case "Low":
            // Return lowest quality (excluding Auto)
            return qualities.count > 1 ? qualities.last! : qualities[0]
            
        default:
            // Default to Auto
            return qualities[0]
        }
    }
    
    /// The original download method (adapted to be called internally)
    /// This method should match the existing download implementation in JSController-Downloads.swift
    private func downloadWithOriginalMethod(url: URL, headers: [String: String], title: String? = nil, completionHandler: ((Bool, String) -> Void)? = nil) {
        // Call the existing download method
        self.startDownload(
            url: url,
            headers: headers,
            title: title,
            completionHandler: completionHandler
        )
    }
}

// MARK: - Private API Compatibility Extension
// This extension ensures compatibility with the existing JSController-Downloads.swift implementation
private extension JSController {
    // No longer needed since JSController-Downloads.swift has been implemented
    // Remove the duplicate startDownload method to avoid conflicts
} 