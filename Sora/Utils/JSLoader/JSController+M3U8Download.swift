//
//  JSController+M3U8Download.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
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
    ///   - imageURL: Image URL for the content (optional)
    ///   - isEpisode: Whether this is an episode (defaults to false)
    ///   - showTitle: Title of the show this episode belongs to (optional)
    ///   - season: Season number (optional)
    ///   - episode: Episode number (optional)
    ///   - subtitleURL: Optional subtitle URL to download after video (optional)
    ///   - completionHandler: Called when the download is initiated or fails
    func downloadWithM3U8Support(url: URL, headers: [String: String], title: String? = nil, 
                                imageURL: URL? = nil, isEpisode: Bool = false, 
                                showTitle: String? = nil, season: Int? = nil, episode: Int? = nil,
                                subtitleURL: URL? = nil, showPosterURL: URL? = nil,
                                completionHandler: ((Bool, String) -> Void)? = nil) {
        // Use headers passed in from caller rather than generating our own baseUrl
        // Receiving code should already be setting module.metadata.baseUrl
        
        print("---- DOWNLOAD PROCESS STARTED ----")
        print("Original URL: \(url.absoluteString)")
        print("Headers: \(headers)")
        print("Title: \(title ?? "None")")
        print("Is Episode: \(isEpisode), Show: \(showTitle ?? "None"), Season: \(season?.description ?? "None"), Episode: \(episode?.description ?? "None")")
        if let subtitle = subtitleURL {
            print("Subtitle URL: \(subtitle.absoluteString)")
        }
        
        // Check if the URL is an M3U8 file
        if url.absoluteString.contains(".m3u8") {
            // Get the user's quality preference
            let preferredQuality = DownloadQualityPreference.current.rawValue
            
            print("URL detected as M3U8 playlist - will select quality based on user preference: \(preferredQuality)")
            
            // Parse the M3U8 content to extract available qualities, matching CustomPlayer approach
            parseM3U8(url: url, baseUrl: url.absoluteString, headers: headers) { [weak self] qualities in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if qualities.isEmpty {
                        print("M3U8 Analysis: No quality options found in M3U8, downloading with original URL")
                        self.downloadWithOriginalMethod(
                            url: url,
                            headers: headers,
                            title: title,
                            imageURL: imageURL,
                            isEpisode: isEpisode,
                            showTitle: showTitle,
                            season: season,
                            episode: episode,
                            subtitleURL: subtitleURL,
                            showPosterURL: showPosterURL,
                            completionHandler: completionHandler
                        )
                        return
                    }
                    
                    print("M3U8 Analysis: Found \(qualities.count) quality options")
                    for (index, quality) in qualities.enumerated() {
                        print("  \(index + 1). \(quality.0) - \(quality.1)")
                    }
                    
                    // Select appropriate quality based on user preference
                    let selectedQuality = self.selectQualityBasedOnPreference(qualities: qualities, preferredQuality: preferredQuality)
                    
                    print("M3U8 Analysis: Selected quality: \(selectedQuality.0)")
                    print("M3U8 Analysis: Selected URL: \(selectedQuality.1)")
                    
                    if let qualityURL = URL(string: selectedQuality.1) {
                        print("FINAL DOWNLOAD URL: \(qualityURL.absoluteString)")
                        print("QUALITY SELECTED: \(selectedQuality.0)")
                        
                        // Download with standard headers that match the player
                        self.downloadWithOriginalMethod(
                            url: qualityURL,
                            headers: headers,
                            title: title,
                            imageURL: imageURL,
                            isEpisode: isEpisode,
                            showTitle: showTitle,
                            season: season,
                            episode: episode,
                            subtitleURL: subtitleURL,
                            showPosterURL: showPosterURL,
                            completionHandler: completionHandler
                        )
                    } else {
                        print("M3U8 Analysis: Invalid quality URL, falling back to original URL")
                        print("FINAL DOWNLOAD URL (fallback): \(url.absoluteString)")
                        
                        self.downloadWithOriginalMethod(
                            url: url,
                            headers: headers,
                            title: title,
                            imageURL: imageURL,
                            isEpisode: isEpisode,
                            showTitle: showTitle,
                            season: season,
                            episode: episode,
                            subtitleURL: subtitleURL,
                            showPosterURL: showPosterURL,
                            completionHandler: completionHandler
                        )
                    }
                }
            }
        } else {
            // Not an M3U8 file, use the original download method with standard headers
            print("URL is not an M3U8 playlist - downloading directly")
            print("FINAL DOWNLOAD URL (direct): \(url.absoluteString)")
            
            downloadWithOriginalMethod(
                url: url,
                headers: headers,
                title: title,
                imageURL: imageURL,
                isEpisode: isEpisode,
                showTitle: showTitle,
                season: season,
                episode: episode,
                subtitleURL: subtitleURL,
                showPosterURL: showPosterURL,
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
        
        print("M3U8 Parser: Fetching M3U8 content from: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Log HTTP status for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("M3U8 Parser: HTTP Status: \(httpResponse.statusCode) for \(url.absoluteString)")
                
                if httpResponse.statusCode >= 400 {
                    print("M3U8 Parser: HTTP Error: \(httpResponse.statusCode)")
                    completion([])
                    return
                }
            }
            
            if let error = error {
                print("M3U8 Parser: Error fetching M3U8: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let data = data, let content = String(data: data, encoding: .utf8) else {
                print("M3U8 Parser: Failed to load or decode M3U8 file")
                completion([])
                return
            }
            
            print("M3U8 Parser: Successfully fetched M3U8 content (\(data.count) bytes)")
            
            let lines = content.components(separatedBy: .newlines)
            print("M3U8 Parser: Found \(lines.count) lines in M3U8 file")
            
            var qualities: [(String, String)] = []
            
            // Always include the original URL as "Auto" option
            qualities.append(("Auto (Recommended)", url.absoluteString))
            print("M3U8 Parser: Added 'Auto' quality option with original URL")
            
            func getQualityName(for height: Int) -> String {
                switch height {
                case 1080...: return "\(height)p (FHD)"
                case 720..<1080: return "\(height)p (HD)"
                case 480..<720: return "\(height)p (SD)"
                default: return "\(height)p"
                }
            }
            
            // Parse the M3U8 content to extract available streams - exactly like CustomPlayer
            print("M3U8 Parser: Scanning for quality options...")
            var qualitiesFound = 0
            
            for (index, line) in lines.enumerated() {
                if line.contains("#EXT-X-STREAM-INF"), index + 1 < lines.count {
                    print("M3U8 Parser: Found stream info at line \(index): \(line)")
                    
                    if let resolutionRange = line.range(of: "RESOLUTION="),
                       let resolutionEndRange = line[resolutionRange.upperBound...].range(of: ",")
                        ?? line[resolutionRange.upperBound...].range(of: "\n") {
                        
                        let resolutionPart = String(line[resolutionRange.upperBound..<resolutionEndRange.lowerBound])
                        print("M3U8 Parser: Extracted resolution: \(resolutionPart)")
                        
                        if let heightStr = resolutionPart.components(separatedBy: "x").last,
                           let height = Int(heightStr) {
                            
                            let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                            let qualityName = getQualityName(for: height)
                            
                            print("M3U8 Parser: Found height \(height)px, quality name: \(qualityName)")
                            print("M3U8 Parser: Stream URL from next line: \(nextLine)")
                            
                            var qualityURL = nextLine
                            if !nextLine.hasPrefix("http") && nextLine.contains(".m3u8") {
                                // Handle relative URLs
                                let baseURLString = url.deletingLastPathComponent().absoluteString
                                let resolvedURL = URL(string: nextLine, relativeTo: url)?.absoluteString
                                    ?? baseURLString + "/" + nextLine
                                
                                qualityURL = resolvedURL
                                print("M3U8 Parser: Resolved relative URL to: \(qualityURL)")
                            }
                            
                            if !qualities.contains(where: { $0.0 == qualityName }) {
                                qualities.append((qualityName, qualityURL))
                                qualitiesFound += 1
                                print("M3U8 Parser: Added quality option: \(qualityName) - \(qualityURL)")
                            } else {
                                print("M3U8 Parser: Skipped duplicate quality: \(qualityName)")
                            }
                        } else {
                            print("M3U8 Parser: Failed to extract height from resolution: \(resolutionPart)")
                        }
                    } else {
                        print("M3U8 Parser: Failed to extract resolution from line: \(line)")
                    }
                }
            }
            
            print("M3U8 Parser: Found \(qualitiesFound) distinct quality options (plus Auto)")
            print("M3U8 Parser: Total quality options: \(qualities.count)")
            completion(qualities)
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
            print("Quality Selection: Only one quality option available, returning it directly")
            return qualities[0]
        }
        
        // Extract "Auto" quality and the remaining qualities
        let autoQuality = qualities.first { $0.0.contains("Auto") }
        let nonAutoQualities = qualities.filter { !$0.0.contains("Auto") }
        
        print("Quality Selection: Found \(nonAutoQualities.count) non-Auto quality options")
        print("Quality Selection: Auto quality option: \(autoQuality?.0 ?? "None")")
        
        // Sort non-auto qualities by resolution (highest first)
        let sortedQualities = nonAutoQualities.sorted { first, second in
            let firstHeight = Int(first.0.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
            let secondHeight = Int(second.0.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
            return firstHeight > secondHeight
        }
        
        print("Quality Selection: Sorted qualities (highest to lowest):")
        for (index, quality) in sortedQualities.enumerated() {
            print("  \(index + 1). \(quality.0) - \(quality.1)")
        }
        
        print("Quality Selection: User preference is '\(preferredQuality)'")
        
        // Select quality based on preference
        switch preferredQuality {
        case "Best":
            // Return the highest quality (first in sorted list)
            let selected = sortedQualities.first ?? qualities[0]
            print("Quality Selection: Selected 'Best' quality: \(selected.0)")
            return selected
            
        case "High":
            // Look for 720p quality
            let highQuality = sortedQualities.first {
                $0.0.contains("720p") || $0.0.contains("HD")
            }
            
            if let high = highQuality {
                print("Quality Selection: Found specific 'High' (720p/HD) quality: \(high.0)")
                return high
            } else if let first = sortedQualities.first {
                print("Quality Selection: No specific 'High' quality found, using highest available: \(first.0)")
                return first
            } else {
                print("Quality Selection: No non-Auto qualities found, falling back to default: \(qualities[0].0)")
                return qualities[0]
            }
            
        case "Medium":
            // Look for 480p quality
            let mediumQuality = sortedQualities.first {
                $0.0.contains("480p") || $0.0.contains("SD")
            }
            
            if let medium = mediumQuality {
                print("Quality Selection: Found specific 'Medium' (480p/SD) quality: \(medium.0)")
                return medium
            } else if !sortedQualities.isEmpty {
                // Return middle quality from sorted list if no exact match
                let middleIndex = sortedQualities.count / 2
                print("Quality Selection: No specific 'Medium' quality found, using middle quality: \(sortedQualities[middleIndex].0)")
                return sortedQualities[middleIndex]
            } else {
                print("Quality Selection: No non-Auto qualities found, falling back to default: \(autoQuality?.0 ?? qualities[0].0)")
                return autoQuality ?? qualities[0]
            }
            
        case "Low":
            // Return lowest quality (last in sorted list)
            if let lowest = sortedQualities.last {
                print("Quality Selection: Selected 'Low' quality: \(lowest.0)")
                return lowest
            } else {
                print("Quality Selection: No non-Auto qualities found, falling back to default: \(autoQuality?.0 ?? qualities[0].0)")
                return autoQuality ?? qualities[0]
            }
            
        default:
            // Default to Auto if available, otherwise first quality
            if let auto = autoQuality {
                print("Quality Selection: Default case, using Auto quality: \(auto.0)")
                return auto
            } else {
                print("Quality Selection: No Auto quality found, using first available: \(qualities[0].0)")
                return qualities[0]
            }
        }
    }
    
    /// The original download method (adapted to be called internally)
    /// This method should match the existing download implementation in JSController-Downloads.swift
    private func downloadWithOriginalMethod(url: URL, headers: [String: String], title: String? = nil, 
                                           imageURL: URL? = nil, isEpisode: Bool = false, 
                                           showTitle: String? = nil, season: Int? = nil, episode: Int? = nil,
                                           subtitleURL: URL? = nil, showPosterURL: URL? = nil,
                                           completionHandler: ((Bool, String) -> Void)? = nil) {
        // Call the existing download method
        self.startDownload(
            url: url,
            headers: headers,
            title: title,
            imageURL: imageURL,
            isEpisode: isEpisode,
            showTitle: showTitle,
            season: season,
            episode: episode,
            subtitleURL: subtitleURL,
            showPosterURL: showPosterURL,
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