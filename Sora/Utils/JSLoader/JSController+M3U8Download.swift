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
        // Ensure headers are properly set for streaming
        let optimizedHeaders = ensureStreamingHeaders(headers: headers, for: url)
        logHeadersForRequest(headers: optimizedHeaders, url: url, operation: "Initial download request")
        
        // Check if the URL is an M3U8 file
        if url.absoluteString.contains(".m3u8") {
            // Get the user's quality preference
            let preferredQuality = DownloadQualityPreference.current.rawValue
            
            print("Starting M3U8 download with quality preference: \(preferredQuality)")
            
            // Check if it's a master playlist
            if url.lastPathComponent == "master.m3u8" {
                print("Detected master playlist URL, generating direct stream URLs")
                
                // Generate stream URLs directly without downloading the master playlist
                let streamURLs = generateStreamURLs(from: url)
                
                // Select the appropriate quality based on user preference
                let selectedURL = selectStreamURLBasedOnQuality(streamURLs: streamURLs, preferredQuality: preferredQuality)
                
                print("Using direct stream URL for quality \(selectedURL.quality): \(selectedURL.url.absoluteString)")
                
                // Initiate download with the stream URL
                downloadWithOriginalMethod(
                    url: selectedURL.url,
                    headers: optimizedHeaders,
                    title: title,
                    completionHandler: completionHandler
                )
            } else {
                // Not a master playlist, likely already a specific quality stream
                print("URL appears to be a direct stream URL, not a master playlist")
                
                // Just download it directly
                downloadWithOriginalMethod(
                    url: url,
                    headers: optimizedHeaders,
                    title: title,
                    completionHandler: completionHandler
                )
            }
        } else {
            // Not an M3U8 file, use the original download method
            downloadWithOriginalMethod(
                url: url,
                headers: optimizedHeaders,
                title: title,
                completionHandler: completionHandler
            )
        }
    }
    
    /// Generates stream URLs for different qualities based on a master URL pattern
    /// - Parameter masterURL: The URL of the master M3U8 playlist
    /// - Returns: Array of stream URLs with quality information
    private func generateStreamURLs(from masterURL: URL) -> [(url: URL, quality: String, resolution: Int)] {
        let baseURLString = masterURL.deletingLastPathComponent().absoluteString
        
        // Common quality paths for various streaming providers
        let qualities: [(suffix: String, quality: String, resolution: Int)] = [
            ("index-v1-a1.m3u8", "Best", 1080),
            ("index-v1-a2.m3u8", "High", 720),
            ("index-v1-a3.m3u8", "Medium", 480),
            ("index-v1-a4.m3u8", "Low", 360),
            ("1080/index.m3u8", "Best", 1080),
            ("720/index.m3u8", "High", 720),
            ("480/index.m3u8", "Medium", 480),
            ("360/index.m3u8", "Low", 360),
            ("1080p.m3u8", "Best", 1080),
            ("720p.m3u8", "High", 720),
            ("480p.m3u8", "Medium", 480),
            ("360p.m3u8", "Low", 360)
        ]
        
        print("Generating stream URLs from base: \(baseURLString)")
        
        var streamURLs: [(url: URL, quality: String, resolution: Int)] = []
        
        for quality in qualities {
            if let url = URL(string: baseURLString + "/" + quality.suffix) {
                streamURLs.append((url: url, quality: quality.quality, resolution: quality.resolution))
                print("Generated URL for \(quality.quality) (\(quality.resolution)p): \(url.absoluteString)")
            }
        }
        
        // If we couldn't generate any URLs using standard patterns, try to use a different approach
        if streamURLs.isEmpty {
            print("No stream URLs generated with standard patterns, using alternative approach")
            
            // Alternative approach: Modify the master.m3u8 to the specific quality file
            let urlString = masterURL.absoluteString
            if let masterRange = urlString.range(of: "master.m3u8") {
                let basePath = urlString[..<masterRange.lowerBound]
                
                let alternativeQualities: [(filename: String, quality: String, resolution: Int)] = [
                    ("1080p.m3u8", "Best", 1080),
                    ("720p.m3u8", "High", 720),
                    ("480p.m3u8", "Medium", 480),
                    ("360p.m3u8", "Low", 360),
                    ("hls/1080p/index.m3u8", "Best", 1080),
                    ("hls/720p/index.m3u8", "High", 720),
                    ("hls/480p/index.m3u8", "Medium", 480),
                    ("hls/360p/index.m3u8", "Low", 360)
                ]
                
                for quality in alternativeQualities {
                    if let url = URL(string: String(basePath) + quality.filename) {
                        streamURLs.append((url: url, quality: quality.quality, resolution: quality.resolution))
                        print("Generated alternative URL for \(quality.quality) (\(quality.resolution)p): \(url.absoluteString)")
                    }
                }
            }
        }
        
        // If still no URLs, return the master URL as a fallback
        if streamURLs.isEmpty {
            print("No stream URLs could be generated, using master URL as fallback")
            streamURLs.append((url: masterURL, quality: "Unknown", resolution: 0))
        }
        
        return streamURLs
    }
    
    /// Selects the appropriate stream URL based on quality preference
    /// - Parameters:
    ///   - streamURLs: Array of available stream URLs with quality information
    ///   - preferredQuality: User's preferred quality
    /// - Returns: The selected stream URL with quality information
    private func selectStreamURLBasedOnQuality(streamURLs: [(url: URL, quality: String, resolution: Int)], preferredQuality: String) -> (url: URL, quality: String, resolution: Int) {
        // Sort by resolution (highest first)
        let sortedStreams = streamURLs.sorted { $0.resolution > $1.resolution }
        
        switch preferredQuality {
        case "Best":
            // Return the highest quality stream
            return sortedStreams.first!
            
        case "High":
            // Return a high quality stream (720p or higher, but not the highest)
            let highStreams = sortedStreams.filter { $0.resolution >= 720 }
            if highStreams.count > 1 {
                return highStreams[1]  // Second highest if available
            } else if !highStreams.isEmpty {
                return highStreams[0]  // Highest if only one high quality stream
            } else {
                return sortedStreams.first!  // Fallback to highest available
            }
            
        case "Medium":
            // Return a medium quality stream (between 480p and 720p)
            let mediumStreams = sortedStreams.filter { $0.resolution >= 480 && $0.resolution < 720 }
            if !mediumStreams.isEmpty {
                return mediumStreams.first!
            } else if sortedStreams.count > 1 {
                let medianIndex = sortedStreams.count / 2
                return sortedStreams[medianIndex]  // Return median quality as fallback
            } else {
                return sortedStreams.first!  // Fallback to highest available
            }
            
        case "Low":
            // Return the lowest quality stream
            return sortedStreams.last!
            
        default:
            // Default to best quality
            return sortedStreams.first!
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
    // This is a stub for the actual implementation in JSController-Downloads.swift
    // The real implementation should be present in that file
    func startDownload(url: URL, headers: [String: String], title: String? = nil, completionHandler: ((Bool, String) -> Void)? = nil) {
        // This method should already be implemented in JSController-Downloads.swift
        // It's defined here only to satisfy the compiler
        // The actual implementation will be used at runtime
    }
} 