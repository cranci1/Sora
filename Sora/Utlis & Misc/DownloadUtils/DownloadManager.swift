//
//  DownloadManager.swift
//  Sulfur
//
//  Created by Francesco on 29/04/25.
//

import SwiftUI
import AVKit
import AVFoundation

class DownloadManager: NSObject, ObservableObject {
    @Published var activeDownloads: [(URL, Double)] = []
    @Published var localPlaybackURL: URL?
    
    private var assetDownloadURLSession: AVAssetDownloadURLSession!
    private var activeDownloadTasks: [URLSessionTask: URL] = [:]
    
    override init() {
        super.init()
        initializeDownloadSession()
        loadLocalContent()
    }
    
    private func initializeDownloadSession() {
        #if targetEnvironment(simulator)
            Logger.shared.log("Download Sessions are not available on Simulator", type: "Error")
        #else
            let configuration = URLSessionConfiguration.background(withIdentifier: "hls-downloader")

            assetDownloadURLSession = AVAssetDownloadURLSession(
                configuration: configuration,
                assetDownloadDelegate: self,
                delegateQueue: .main
            )
        #endif
    }
    
    func downloadAsset(from url: URL) {
        let asset = AVURLAsset(url: url)
        let task = assetDownloadURLSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: "Offline Video",
            assetArtworkData: nil,
            options: nil
        )
        
        task?.resume()
        activeDownloadTasks[task!] = url
    }
    
    private func loadLocalContent() {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: documents,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            
            if let localURL = contents.first(where: { ["movpkg", "mp4"].contains($0.pathExtension.lowercased()) }) {
                localPlaybackURL = localURL
            }
        } catch {
            Logger.shared.log("Could not load local content: \(error)", type: "Error")
        }
    }
}

extension DownloadManager: AVAssetDownloadDelegate {
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        activeDownloadTasks.removeValue(forKey: assetDownloadTask)
        localPlaybackURL = location
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        Logger.shared.log("Download failed: \(error.localizedDescription)", type: "Error")
        activeDownloadTasks.removeValue(forKey: task)
    }
    
    func urlSession(_ session: URLSession,
                   assetDownloadTask: AVAssetDownloadTask,
                   didLoad timeRange: CMTimeRange,
                   totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                   timeRangeExpectedToLoad: CMTimeRange) {
        
        guard let url = activeDownloadTasks[assetDownloadTask] else { return }
        let progress = loadedTimeRanges
            .map { $0.timeRangeValue.duration.seconds / timeRangeExpectedToLoad.duration.seconds }
            .reduce(0, +)
        
        if let index = activeDownloads.firstIndex(where: { $0.0 == url }) {
            activeDownloads[index].1 = progress
        } else {
            activeDownloads.append((url, progress))
        }
    }
}
