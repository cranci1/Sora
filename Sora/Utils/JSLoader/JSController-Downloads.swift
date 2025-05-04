//
//  JSController-Downloads.swift
//  Sora
//
//  Created by Francesco on 29/04/25.
//

import Foundation
import AVFoundation
import Combine

// MARK: - Data Models
struct DownloadedAsset: Identifiable, Codable {
    let id: UUID
    var name: String
    let downloadDate: Date
    let originalURL: URL
    let localURL: URL
    var fileSize: Int64?
    
    init(id: UUID = UUID(), name: String, downloadDate: Date, originalURL: URL, localURL: URL) {
        self.id = id
        self.name = name
        self.downloadDate = downloadDate
        self.originalURL = originalURL
        self.localURL = localURL
        self.fileSize = getFileSize()
    }
    
    func getFileSize() -> Int64? {
        do {
            let values = try localURL.resourceValues(forKeys: [.fileSizeKey])
            return Int64(values.fileSize ?? 0)
        } catch {
            return nil
        }
    }
}

struct ActiveDownload: Identifiable {
    let id: UUID
    let originalURL: URL
    var progress: Double
    let task: URLSessionTask
}

extension URL {
    static func isValidHLSURL(string: String) -> Bool {
        guard let url = URL(string: string), url.pathExtension == "m3u8" else { return false }
        return true
    }
}

// MARK: - Download Manager Extension
extension JSController {
    // Class properties for downloads
    private struct DownloadProperties {
        static var activeDownloads: [ActiveDownload] = []
        static var savedAssets: [DownloadedAsset] = []
        static var assetDownloadURLSession: AVAssetDownloadURLSession?
        static var activeDownloadTasks: [URLSessionTask: URL] = [:]
    }
    
    // Setup download session
    func initializeDownloadSession() {
        let configuration = URLSessionConfiguration.background(withIdentifier: "hls-downloader-\(UUID().uuidString)")
        DownloadProperties.assetDownloadURLSession = AVAssetDownloadURLSession(
            configuration: configuration,
            assetDownloadDelegate: self,
            delegateQueue: .main
        )
        loadSavedAssets()
        reconcileFileSystemAssets()
    }
    
    // MARK: - Public Download Functions
    
    // Get active downloads
    var activeDownloads: [ActiveDownload] {
        return DownloadProperties.activeDownloads
    }
    
    // Get saved assets
    var savedAssets: [DownloadedAsset] {
        return DownloadProperties.savedAssets
    }
    
    // Download an asset from URL
    func downloadAsset(from url: URL, headers: [String: String] = [:]) {
        guard !DownloadProperties.savedAssets.contains(where: { $0.originalURL == url }) else {
            Logger.shared.log("Asset already downloaded", type: "Download")
            return
        }
        
        if DownloadProperties.assetDownloadURLSession == nil {
            initializeDownloadSession()
        }
        
        guard let session = DownloadProperties.assetDownloadURLSession else {
            Logger.shared.log("Failed to initialize download session", type: "Error")
            return
        }
        
        // Create request with headers
        var urlRequest = URLRequest(url: url)
        
        // Add User-Agent header
        urlRequest.addValue(URLSession.randomUserAgent, forHTTPHeaderField: "User-Agent")
        
        // Add custom headers
        for (key, value) in headers {
            urlRequest.addValue(value, forHTTPHeaderField: key)
        }
        
        // Default headers if none provided
        if headers.isEmpty {
            urlRequest.addValue("*/*", forHTTPHeaderField: "Origin")
            urlRequest.addValue("*/*", forHTTPHeaderField: "Referer")
        }
        
        let asset = AVURLAsset(url: urlRequest.url!, options: ["AVURLAssetHTTPHeaderFieldsKey": urlRequest.allHTTPHeaderFields ?? [:]])
        
        let task = session.makeAssetDownloadTask(
            asset: asset,
            assetTitle: url.lastPathComponent,
            assetArtworkData: nil,
            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 2_000_000]
        )
        
        guard let downloadTask = task else {
            Logger.shared.log("Failed to create download task", type: "Error")
            return
        }
        
        let download = ActiveDownload(
            id: UUID(),
            originalURL: url,
            progress: 0,
            task: downloadTask
        )
        
        DownloadProperties.activeDownloads.append(download)
        DownloadProperties.activeDownloadTasks[downloadTask] = url
        downloadTask.resume()
        
        Logger.shared.log("Started downloading asset: \(url.lastPathComponent)", type: "Download")
    }
    
    // Download asset from string URL
    func downloadAsset(fromString urlString: String, headers: [String: String] = [:]) {
        // Check if the string looks like HTML (contains basic HTML tags)
        if urlString.contains("<html") || urlString.contains("<!DOCTYPE") {
            Logger.shared.log("Received HTML content instead of URL. Attempting to extract URL.", type: "Warning")
            
            // Try to extract a video URL from the HTML content
            // Look for common video URL patterns like m3u8 extensions or video domains
            if let m3u8Range = urlString.range(of: "https?://[^\\s\"']+\\.m3u8[^\\s\"']*", options: .regularExpression) {
                let extractedUrl = String(urlString[m3u8Range])
                Logger.shared.log("Extracted URL from HTML: \(extractedUrl)", type: "Download")
                downloadAsset(fromString: extractedUrl, headers: headers)
                return
            } else if let mp4Range = urlString.range(of: "https?://[^\\s\"']+\\.mp4[^\\s\"']*", options: .regularExpression) {
                let extractedUrl = String(urlString[mp4Range])
                Logger.shared.log("Extracted URL from HTML: \(extractedUrl)", type: "Download")
                downloadAsset(fromString: extractedUrl, headers: headers)
                return
            } else {
                Logger.shared.log("Failed to extract video URL from HTML content", type: "Error")
                return
            }
        }
        
        guard let url = URL(string: urlString) else {
            Logger.shared.log("Invalid URL: \(urlString)", type: "Error")
            return
        }
        downloadAsset(from: url, headers: headers)
    }
    
    // Delete an asset
    func deleteAsset(_ asset: DownloadedAsset) {
        do {
            try FileManager.default.removeItem(at: asset.localURL)
            DownloadProperties.savedAssets.removeAll { $0.id == asset.id }
            saveAssets()
            Logger.shared.log("Deleted asset: \(asset.name)", type: "Download")
        } catch {
            Logger.shared.log("Error deleting asset: \(error)", type: "Error")
        }
    }
    
    // Rename an asset
    func renameAsset(_ asset: DownloadedAsset, newName: String) {
        guard let index = DownloadProperties.savedAssets.firstIndex(where: { $0.id == asset.id }) else { 
            Logger.shared.log("Asset not found for renaming", type: "Error")
            return 
        }
        DownloadProperties.savedAssets[index].name = newName
        saveAssets()
        Logger.shared.log("Renamed asset to: \(newName)", type: "Download")
    }
    
    // MARK: - Persistence
    private func saveAssets() {
        do {
            let data = try JSONEncoder().encode(DownloadProperties.savedAssets)
            UserDefaults.standard.set(data, forKey: "savedVideoAssets")
        } catch {
            Logger.shared.log("Error saving assets: \(error)", type: "Error")
        }
    }
    
    private func loadSavedAssets() {
        guard let data = UserDefaults.standard.data(forKey: "savedVideoAssets") else { return }
        do {
            DownloadProperties.savedAssets = try JSONDecoder().decode([DownloadedAsset].self, from: data)
            Logger.shared.log("Loaded \(DownloadProperties.savedAssets.count) saved assets", type: "Download")
        } catch {
            Logger.shared.log("Error loading saved assets: \(error)", type: "Error")
        }
    }
    
    private func reconcileFileSystemAssets() {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documents,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            for url in fileURLs where url.pathExtension == "movpkg" {
                if !DownloadProperties.savedAssets.contains(where: { $0.localURL == url }) {
                    let newAsset = DownloadedAsset(
                        name: url.deletingPathExtension().lastPathComponent,
                        downloadDate: Date(),
                        originalURL: url, // This is a fallback since we don't know the original URL
                        localURL: url
                    )
                    DownloadProperties.savedAssets.append(newAsset)
                    Logger.shared.log("Reconciled asset from filesystem: \(newAsset.name)", type: "Download")
                }
            }
            saveAssets()
        } catch {
            Logger.shared.log("Error reconciling files: \(error)", type: "Error")
        }
    }
    
    // JavaScript-accessible download function
    func setupDownloadFunction() {
        let downloadFunction: @convention(block) (String, String) -> Bool = { [weak self] (urlString, name) in
            guard let self = self, let url = URL(string: urlString) else { return false }
            
            DispatchQueue.main.async {
                self.downloadAsset(from: url)
            }
            return true
        }
        
        context.setObject(downloadFunction, forKeyedSubscript: "downloadStream" as NSString)
    }
    
    // Cleanup download task
    private func cleanupDownloadTask(_ task: URLSessionTask) {
        DownloadProperties.activeDownloadTasks.removeValue(forKey: task)
        DownloadProperties.activeDownloads.removeAll { $0.task == task }
    }
}

// MARK: - AVAssetDownloadDelegate
extension JSController: AVAssetDownloadDelegate {
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard let originalURL = DownloadProperties.activeDownloadTasks[assetDownloadTask] else { 
            Logger.shared.log("Original URL not found for completed download", type: "Error")
            return 
        }
        
        let newAsset = DownloadedAsset(
            name: originalURL.lastPathComponent,
            downloadDate: Date(),
            originalURL: originalURL,
            localURL: location
        )
        
        DownloadProperties.savedAssets.append(newAsset)
        saveAssets()
        cleanupDownloadTask(assetDownloadTask)
        
        Logger.shared.log("Successfully downloaded asset: \(newAsset.name)", type: "Download")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Logger.shared.log("Download error: \(error.localizedDescription)", type: "Error")
        }
        cleanupDownloadTask(task)
    }
    
    func urlSession(_ session: URLSession,
                   assetDownloadTask: AVAssetDownloadTask,
                   didLoad timeRange: CMTimeRange,
                   totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                   timeRangeExpectedToLoad: CMTimeRange) {
        guard let originalURL = DownloadProperties.activeDownloadTasks[assetDownloadTask],
              let downloadIndex = DownloadProperties.activeDownloads.firstIndex(where: { $0.originalURL == originalURL }) else { return }
        
        let progress = loadedTimeRanges
            .map { $0.timeRangeValue.duration.seconds / timeRangeExpectedToLoad.duration.seconds }
            .reduce(0, +)
        
        DownloadProperties.activeDownloads[downloadIndex].progress = progress
    }
}
