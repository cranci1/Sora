//
//  JSController+Downloader.swift
//  Sora
//
//  Created by doomsboygaming on 6/13/25
//

import Foundation
import SwiftUI
import AVFoundation

struct DownloadRequest {
    let url: URL
    let headers: [String: String]
    let title: String?
    let imageURL: URL?
    let isEpisode: Bool
    let showTitle: String?
    let season: Int?
    let episode: Int?
    let subtitleURL: URL?
    let showPosterURL: URL?
    
    init(url: URL, headers: [String: String], title: String? = nil, imageURL: URL? = nil, 
         isEpisode: Bool = false, showTitle: String? = nil, season: Int? = nil, 
         episode: Int? = nil, subtitleURL: URL? = nil, showPosterURL: URL? = nil) {
        self.url = url
        self.headers = headers
        self.title = title
        self.imageURL = imageURL
        self.isEpisode = isEpisode
        self.showTitle = showTitle
        self.season = season
        self.episode = episode
        self.subtitleURL = subtitleURL
        self.showPosterURL = showPosterURL
    }
}

struct QualityOption {
    let name: String
    let url: String
    let height: Int?
    
    init(name: String, url: String, height: Int? = nil) {
        self.name = name
        self.url = url
        self.height = height
    }
}

extension JSController {
    
    func downloadWithM3U8Support(url: URL, headers: [String: String], title: String? = nil, 
                                imageURL: URL? = nil, isEpisode: Bool = false, 
                                showTitle: String? = nil, season: Int? = nil, episode: Int? = nil,
                                subtitleURL: URL? = nil, showPosterURL: URL? = nil,
                                completionHandler: ((Bool, String) -> Void)? = nil) {
        
        let request = DownloadRequest(
            url: url, headers: headers, title: title, imageURL: imageURL,
            isEpisode: isEpisode, showTitle: showTitle, season: season, 
            episode: episode, subtitleURL: subtitleURL, showPosterURL: showPosterURL
        )
        
        logDownloadStart(request: request)
        
        if url.absoluteString.contains(".m3u8") {
            handleM3U8Download(request: request, completionHandler: completionHandler)
        } else {
            handleDirectDownload(request: request, completionHandler: completionHandler)
        }
    }
    
    
    private func handleM3U8Download(request: DownloadRequest, completionHandler: ((Bool, String) -> Void)?) {
        let preferredQuality = DownloadQualityPreference.current.rawValue
        logM3U8Detection(preferredQuality: preferredQuality)
        
        parseM3U8(url: request.url, headers: request.headers) { [weak self] qualities in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if qualities.isEmpty {
                    self.logM3U8NoQualities()
                    self.downloadWithOriginalMethod(request: request, completionHandler: completionHandler)
                    return
                }
                
                self.logM3U8QualitiesFound(qualities: qualities)
                let selectedQuality = self.selectQualityBasedOnPreference(qualities: qualities, preferredQuality: preferredQuality)
                self.logM3U8QualitySelected(quality: selectedQuality)
                
                if let qualityURL = URL(string: selectedQuality.url) {
                    let qualityRequest = DownloadRequest(
                        url: qualityURL, headers: request.headers, title: request.title,
                        imageURL: request.imageURL, isEpisode: request.isEpisode, 
                        showTitle: request.showTitle, season: request.season,
                        episode: request.episode, subtitleURL: request.subtitleURL,
                        showPosterURL: request.showPosterURL
                    )
                    self.downloadWithOriginalMethod(request: qualityRequest, completionHandler: completionHandler)
                } else {
                    self.logM3U8InvalidURL()
                    self.downloadWithOriginalMethod(request: request, completionHandler: completionHandler)
                }
            }
        }
    }
    
    private func handleDirectDownload(request: DownloadRequest, completionHandler: ((Bool, String) -> Void)?) {
        logDirectDownload()
        
        let urlString = request.url.absoluteString.lowercased()
        if urlString.contains(".mp4") || urlString.contains("mp4") {
            logMP4Detection()
            downloadMP4(request: request, completionHandler: completionHandler)
        } else {
            downloadWithOriginalMethod(request: request, completionHandler: completionHandler)
        }
    }
    
    
    func downloadMP4(url: URL, headers: [String: String], title: String? = nil, 
                   imageURL: URL? = nil, isEpisode: Bool = false, 
                   showTitle: String? = nil, season: Int? = nil, episode: Int? = nil,
                   subtitleURL: URL? = nil, showPosterURL: URL? = nil,
                   completionHandler: ((Bool, String) -> Void)? = nil) {
        
        let request = DownloadRequest(
            url: url, headers: headers, title: title, imageURL: imageURL,
            isEpisode: isEpisode, showTitle: showTitle, season: season,
            episode: episode, subtitleURL: subtitleURL, showPosterURL: showPosterURL
        )
        
        downloadMP4(request: request, completionHandler: completionHandler)
    }
    
    private func downloadMP4(request: DownloadRequest, completionHandler: ((Bool, String) -> Void)?) {
        guard validateURL(request.url) else {
            completionHandler?(false, "Invalid URL scheme")
            return
        }
        
        guard let downloadSession = downloadURLSession else {
            completionHandler?(false, "Download session not available")
            return
        }
        
        let metadata = createAssetMetadata(from: request)
        let downloadType: DownloadType = request.isEpisode ? .episode : .movie
        let downloadID = UUID()
        
        let asset = AVURLAsset(url: request.url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": request.headers
        ])
        
        guard let downloadTask = downloadSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: request.title ?? request.url.lastPathComponent,
            assetArtworkData: nil,
            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 2_000_000]
        ) else {
            completionHandler?(false, "Failed to create download task")
            return
        }
        
        let activeDownload = createActiveDownload(
            id: downloadID, request: request, asset: asset, 
            downloadTask: downloadTask, downloadType: downloadType, metadata: metadata
        )
        
        addActiveDownload(activeDownload, task: downloadTask)
        setupMP4ProgressObservation(for: downloadTask, downloadID: downloadID)
        downloadTask.resume()
        
        postDownloadNotification()
        completionHandler?(true, "Download started")
    }
    
    
    private func parseM3U8(url: URL, headers: [String: String], completion: @escaping ([QualityOption]) -> Void) {
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        logM3U8FetchStart(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                self.logHTTPStatus(httpResponse.statusCode, for: url)
                if httpResponse.statusCode >= 400 {
                    completion([])
                    return
                }
            }
            
            if let error = error {
                self.logM3U8FetchError(error)
                completion([])
                return
            }
            
            guard let data = data, let content = String(data: data, encoding: .utf8) else {
                self.logM3U8DecodeError()
                completion([])
                return
            }
            
            self.logM3U8FetchSuccess(dataSize: data.count)
            let qualities = self.parseM3U8Content(content: content, baseURL: url)
            completion(qualities)
        }.resume()
    }
    
    private func parseM3U8Content(content: String, baseURL: URL) -> [QualityOption] {
        let lines = content.components(separatedBy: .newlines)
        logM3U8ParseStart(lineCount: lines.count)
        
        var qualities: [QualityOption] = []
        qualities.append(QualityOption(name: "Auto (Recommended)", url: baseURL.absoluteString))
        
        for (index, line) in lines.enumerated() {
            if line.contains("#EXT-X-STREAM-INF"), index + 1 < lines.count {
                if let qualityOption = parseStreamInfoLine(line: line, nextLine: lines[index + 1], baseURL: baseURL) {
                    if !qualities.contains(where: { $0.name == qualityOption.name }) {
                        qualities.append(qualityOption)
                        logM3U8QualityAdded(quality: qualityOption)
                    }
                }
            }
        }
        
        logM3U8ParseComplete(qualityCount: qualities.count - 1) // -1 for Auto
        return qualities
    }
    
    private func parseStreamInfoLine(line: String, nextLine: String, baseURL: URL) -> QualityOption? {
        guard let resolutionRange = line.range(of: "RESOLUTION="),
              let resolutionEndRange = line[resolutionRange.upperBound...].range(of: ",")
                ?? line[resolutionRange.upperBound...].range(of: "\n") else {
            return nil
        }
        
        let resolutionPart = String(line[resolutionRange.upperBound..<resolutionEndRange.lowerBound])
        guard let heightStr = resolutionPart.components(separatedBy: "x").last,
              let height = Int(heightStr) else {
            return nil
        }
        
        let qualityName = getQualityName(for: height)
        let qualityURL = resolveQualityURL(nextLine.trimmingCharacters(in: .whitespacesAndNewlines), baseURL: baseURL)
        
        return QualityOption(name: qualityName, url: qualityURL, height: height)
    }
    
    private func getQualityName(for height: Int) -> String {
        switch height {
        case 1080...: return "\(height)p (FHD)"
        case 720..<1080: return "\(height)p (HD)"
        case 480..<720: return "\(height)p (SD)"
        default: return "\(height)p"
        }
    }
    
    private func resolveQualityURL(_ urlString: String, baseURL: URL) -> String {
        if urlString.hasPrefix("http") {
            return urlString
        }
        
        if urlString.contains(".m3u8") {
            return URL(string: urlString, relativeTo: baseURL)?.absoluteString
                ?? baseURL.deletingLastPathComponent().absoluteString + "/" + urlString
        }
        
        return urlString
    }
    
    
    private func selectQualityBasedOnPreference(qualities: [QualityOption], preferredQuality: String) -> QualityOption {
        guard qualities.count > 1 else {
            logQualitySelectionSingle()
            return qualities[0]
        }
        
        let (autoQuality, sortedQualities) = categorizeQualities(qualities: qualities)
        logQualitySelectionStart(preference: preferredQuality, sortedCount: sortedQualities.count)
        
        let selected = selectQualityByPreference(
            preference: preferredQuality, 
            sortedQualities: sortedQualities, 
            autoQuality: autoQuality, 
            fallback: qualities[0]
        )
        
        logQualitySelectionResult(quality: selected, preference: preferredQuality)
        return selected
    }
    
    private func categorizeQualities(qualities: [QualityOption]) -> (auto: QualityOption?, sorted: [QualityOption]) {
        let autoQuality = qualities.first { $0.name.contains("Auto") }
        let nonAutoQualities = qualities.filter { !$0.name.contains("Auto") }
        
        let sortedQualities = nonAutoQualities.sorted { first, second in
            let firstHeight = first.height ?? extractHeight(from: first.name)
            let secondHeight = second.height ?? extractHeight(from: second.name)
            return firstHeight > secondHeight
        }
        
        return (autoQuality, sortedQualities)
    }
    
    private func selectQualityByPreference(preference: String, sortedQualities: [QualityOption], 
                                         autoQuality: QualityOption?, fallback: QualityOption) -> QualityOption {
        switch preference {
        case "Best":
            return sortedQualities.first ?? fallback
        case "High":
            return findQualityByType(["720p", "HD"], in: sortedQualities) ?? sortedQualities.first ?? fallback
        case "Medium":
            return findQualityByType(["480p", "SD"], in: sortedQualities) 
                ?? (sortedQualities.isEmpty ? fallback : sortedQualities[sortedQualities.count / 2])
        case "Low":
            return sortedQualities.last ?? fallback
        default:
            return autoQuality ?? fallback
        }
    }
    
    private func findQualityByType(_ types: [String], in qualities: [QualityOption]) -> QualityOption? {
        return qualities.first { quality in
            types.contains { quality.name.contains($0) }
        }
    }
    
    private func extractHeight(from qualityName: String) -> Int {
        return Int(qualityName.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
    }
    
    
    private func validateURL(_ url: URL) -> Bool {
        return url.scheme == "http" || url.scheme == "https"
    }
    
    private func createAssetMetadata(from request: DownloadRequest) -> AssetMetadata? {
        guard let title = request.title else { return nil }
        
        return AssetMetadata(
            title: title,
            posterURL: request.imageURL,
            showTitle: request.showTitle,
            season: request.season,
            episode: request.episode,
            showPosterURL: request.showPosterURL ?? request.imageURL
        )
    }
    
    private func createActiveDownload(id: UUID, request: DownloadRequest, asset: AVURLAsset, 
                                    downloadTask: AVAssetDownloadTask? = nil, urlSessionTask: URLSessionDownloadTask? = nil,
                                    downloadType: DownloadType, metadata: AssetMetadata?) -> JSActiveDownload {
        return JSActiveDownload(
            id: id,
            originalURL: request.url,
            progress: 0.0,
            task: downloadTask,
            urlSessionTask: urlSessionTask,
            queueStatus: .downloading,
            type: downloadType,
            metadata: metadata,
            title: request.title,
            imageURL: request.imageURL,
            subtitleURL: request.subtitleURL,
            asset: asset,
            headers: request.headers,
            module: nil
        )
    }
    
    private func addActiveDownload(_ download: JSActiveDownload, task: URLSessionTask) {
        activeDownloads.append(download)
        activeDownloadMap[task] = download.id
    }
    
    private func postDownloadNotification() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("downloadStatusChanged"), object: nil)
        }
    }
    
    private func downloadWithOriginalMethod(request: DownloadRequest, completionHandler: ((Bool, String) -> Void)?) {
        self.startDownload(
            url: request.url,
            headers: request.headers,
            title: request.title,
            imageURL: request.imageURL,
            isEpisode: request.isEpisode,
            showTitle: request.showTitle,
            season: request.season,
            episode: request.episode,
            subtitleURL: request.subtitleURL,
            showPosterURL: request.showPosterURL,
            completionHandler: completionHandler
        )
    }
    
    
    private func setupMP4ProgressObservation(for task: AVAssetDownloadTask, downloadID: UUID) {
        let observation = task.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updateMP4DownloadProgress(task: task, progress: progress.fractionCompleted)
                NotificationCenter.default.post(name: NSNotification.Name("downloadProgressChanged"), object: nil)
            }
        }
        
        if mp4ProgressObservations == nil {
            mp4ProgressObservations = [:]
        }
        mp4ProgressObservations?[downloadID] = observation
    }
    
    private func updateMP4DownloadProgress(task: AVAssetDownloadTask, progress: Double) {
        guard let downloadID = activeDownloadMap[task],
              let downloadIndex = activeDownloads.firstIndex(where: { $0.id == downloadID }) else {
            return
        }
        activeDownloads[downloadIndex].progress = progress
    }
    
    func cleanupMP4ProgressObservation(for downloadID: UUID) {
        mp4ProgressObservations?[downloadID]?.invalidate()
        mp4ProgressObservations?[downloadID] = nil
    }
}


extension JSController {
    private func logDownloadStart(request: DownloadRequest) {
        Logger.shared.log("Download process started for URL: \(request.url.absoluteString)", type: "Download")
        Logger.shared.log("Title: \(request.title ?? "None"), Episode: \(request.isEpisode ? "Yes" : "No")", type: "Debug")
        if let showTitle = request.showTitle, let episode = request.episode {
            Logger.shared.log("Show: \(showTitle), Season: \(request.season ?? 1), Episode: \(episode)", type: "Debug")
        }
        if let subtitle = request.subtitleURL {
            Logger.shared.log("Subtitle URL provided: \(subtitle.absoluteString)", type: "Debug")
        }
    }
    
    private func logM3U8Detection(preferredQuality: String) {
        Logger.shared.log("M3U8 playlist detected - quality preference: \(preferredQuality)", type: "Download")
    }
    
    private func logM3U8NoQualities() {
        Logger.shared.log("No quality options found in M3U8, using original URL", type: "Warning")
    }
    
    private func logM3U8QualitiesFound(qualities: [QualityOption]) {
        Logger.shared.log("Found \(qualities.count) quality options in M3U8 playlist", type: "Download")
        for (index, quality) in qualities.enumerated() {
            Logger.shared.log("Quality \(index + 1): \(quality.name)", type: "Debug")
        }
    }
    
    private func logM3U8QualitySelected(quality: QualityOption) {
        Logger.shared.log("Selected quality: \(quality.name)", type: "Download")
        Logger.shared.log("Final download URL: \(quality.url)", type: "Debug")
    }
    
    private func logM3U8InvalidURL() {
        Logger.shared.log("Invalid quality URL detected, falling back to original", type: "Warning")
    }
    
    private func logDirectDownload() {
        Logger.shared.log("Direct download initiated (non-M3U8)", type: "Download")
    }
    
    private func logMP4Detection() {
        Logger.shared.log("MP4 stream detected, using MP4 download method", type: "Download")
    }
    
    private func logM3U8FetchStart(url: URL) {
        Logger.shared.log("Fetching M3U8 content from: \(url.absoluteString)", type: "Debug")
    }
    
    private func logHTTPStatus(_ statusCode: Int, for url: URL) {
        let logType = statusCode >= 400 ? "Error" : "Debug"
        Logger.shared.log("HTTP \(statusCode) for M3U8 request: \(url.absoluteString)", type: logType)
    }
    
    private func logM3U8FetchError(_ error: Error) {
        Logger.shared.log("Failed to fetch M3U8 content: \(error.localizedDescription)", type: "Error")
    }
    
    private func logM3U8DecodeError() {
        Logger.shared.log("Failed to decode M3U8 file content", type: "Error")
    }
    
    private func logM3U8FetchSuccess(dataSize: Int) {
        Logger.shared.log("Successfully fetched M3U8 content (\(dataSize) bytes)", type: "Debug")
    }
    
    private func logM3U8ParseStart(lineCount: Int) {
        Logger.shared.log("Parsing M3U8 file with \(lineCount) lines", type: "Debug")
    }
    
    private func logM3U8QualityAdded(quality: QualityOption) {
        Logger.shared.log("Added quality option: \(quality.name)", type: "Debug")
    }
    
    private func logM3U8ParseComplete(qualityCount: Int) {
        Logger.shared.log("M3U8 parsing complete: \(qualityCount) quality options found", type: "Debug")
    }
    
    private func logQualitySelectionSingle() {
        Logger.shared.log("Only one quality available, using default", type: "Debug")
    }
    
    private func logQualitySelectionStart(preference: String, sortedCount: Int) {
        Logger.shared.log("Quality selection: \(sortedCount) options, preference: \(preference)", type: "Debug")
    }
    
    private func logQualitySelectionResult(quality: QualityOption, preference: String) {
        Logger.shared.log("Quality selected: \(quality.name) (preference: \(preference))", type: "Download")
    }
}
