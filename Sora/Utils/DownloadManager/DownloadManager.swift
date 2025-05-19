//
//  DownloadManager.swift
//  Sulfur
//
//  Created by Francesco on 29/04/25.
//

import SwiftUI
import AVKit
import Foundation
import AVFoundation

struct DownloadedAsset: Identifiable, Codable {
    let id: UUID
    var name: String
    let downloadDate: Date
    let originalURL: URL
    let localURL: URL
    var fileSize: Int64?
    let module: ScrapingModule
    
    init(id: UUID = UUID(), name: String, downloadDate: Date, originalURL: URL, localURL: URL, module: ScrapingModule) {
        self.id = id
        self.name = name
        self.downloadDate = downloadDate
        self.originalURL = originalURL
        self.localURL = localURL
        self.module = module
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

class DownloadManager: NSObject, ObservableObject {
    @Published var activeDownloads: [ActiveDownload] = []
    @Published var savedAssets: [DownloadedAsset] = []
    
    private var assetDownloadURLSession: AVAssetDownloadURLSession!
    private var activeDownloadTasks: [URLSessionTask: (URL, ScrapingModule)] = [:]
    
    override init() {
        super.init()
        initializeDownloadSession()
        loadSavedAssets()
        reconcileFileSystemAssets()
    }
    
    private func initializeDownloadSession() {
        let configuration = URLSessionConfiguration.background(withIdentifier: "downloader-\(UUID().uuidString)")
        assetDownloadURLSession = AVAssetDownloadURLSession(
            configuration: configuration,
            assetDownloadDelegate: self,
            delegateQueue: .main
        )
    }
    
    func downloadAsset(from url: URL, module: ScrapingModule, headers: [String: String]? = nil) {
        var urlRequest = URLRequest(url: url)
        
        
        if let headers = headers {
            for (key, value) in headers {
                urlRequest.addValue(value, forHTTPHeaderField: key)
            }
        } else {
            urlRequest.addValue(module.metadata.baseUrl, forHTTPHeaderField: "Origin")
            urlRequest.addValue(module.metadata.baseUrl, forHTTPHeaderField: "Referer")
        }
        
        urlRequest.addValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let asset = AVURLAsset(url: urlRequest.url!, options: ["AVURLAssetHTTPHeaderFieldsKey": urlRequest.allHTTPHeaderFields ?? [:]])
        
        let task = assetDownloadURLSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: url.lastPathComponent,
            assetArtworkData: nil,
            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 2_000_000]
        )

        let download = ActiveDownload(
            id: UUID(),
            originalURL: url,
            progress: 0,
            task: task!
        )

        activeDownloads.append(download)
        activeDownloadTasks[task!] = (url, module)
        task?.resume()
    }
    
    func deleteAsset(_ asset: DownloadedAsset) {
        do {
            try FileManager.default.removeItem(at: asset.localURL)
            savedAssets.removeAll { $0.id == asset.id }
            saveAssets()
        } catch {
            Logger.shared.log("Error deleting asset: \(error)")
        }
    }
    
    func renameAsset(_ asset: DownloadedAsset, newName: String) {
        guard let index = savedAssets.firstIndex(where: { $0.id == asset.id }) else { return }
        savedAssets[index].name = newName
        saveAssets()
    }
    
    private func saveAssets() {
        do {
            let data = try JSONEncoder().encode(savedAssets)
            UserDefaults.standard.set(data, forKey: "savedAssets")
        } catch {
            Logger.shared.log("Error saving assets: \(error)")
        }
    }
    
    private func loadSavedAssets() {
        guard let data = UserDefaults.standard.data(forKey: "savedAssets") else { return }
        do {
            savedAssets = try JSONDecoder().decode([DownloadedAsset].self, from: data)
        } catch {
            Logger.shared.log("Error loading saved assets: \(error)")
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
        } catch {
            Logger.shared.log("Error reconciling files: \(error)")
        }
    }
}

extension DownloadManager: AVAssetDownloadDelegate {
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard let (originalURL, module) = activeDownloadTasks[assetDownloadTask] else { return }
        
        let newAsset = DownloadedAsset(
            name: originalURL.lastPathComponent,
            downloadDate: Date(),
            originalURL: originalURL,
            localURL: location,
            module: module
        )
        
        savedAssets.append(newAsset)
        saveAssets()
        cleanupDownloadTask(assetDownloadTask)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        Logger.shared.log("Download error: \(error.localizedDescription)")
        cleanupDownloadTask(task)
    }
    
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        guard let (originalURL, _) = activeDownloadTasks[assetDownloadTask], let downloadIndex = activeDownloads.firstIndex(where: { $0.originalURL == originalURL }) else { return }
        
        let progress = loadedTimeRanges
            .map { $0.timeRangeValue.duration.seconds / timeRangeExpectedToLoad.duration.seconds }
            .reduce(0, +)
        
        activeDownloads[downloadIndex].progress = progress
    }
    
    private func cleanupDownloadTask(_ task: URLSessionTask) {
        activeDownloadTasks.removeValue(forKey: task)
        activeDownloads.removeAll { $0.task == task }
    }
}

struct DownloadProgressView: View {
    let download: ActiveDownload
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(download.originalURL.lastPathComponent)
                .font(.subheadline)
            ProgressView(value: download.progress)
                .progressViewStyle(LinearProgressViewStyle())
            Text("\(Int(download.progress * 100))%")
                .font(.caption)
        }
    }
}

struct AssetRowView: View {
    let asset: DownloadedAsset
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(asset.name)
                .font(.headline)
            Text("\(asset.fileSize ?? 0) bytes • \(asset.downloadDate.formatted())")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ActiveDownload: Identifiable {
    let id: UUID
    let originalURL: URL
    var progress: Double
    let task: URLSessionTask
}
