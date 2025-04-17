//
//  DownloadManager.swift
//  Sulfur
//
//  Created by Francesco on 09/03/25.
//

import Foundation
import FFmpegSupport
import UIKit

class DownloadManager {
    static let shared = DownloadManager()
    
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var activeConversions = [String: Bool]()
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc private func applicationWillResignActive() {
        if !activeConversions.isEmpty {
            backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.endBackgroundTask()
            }
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
    
    func downloadAndConvertHLS(from url: URL, title: String, episode: Int, subtitleURL: URL? = nil, module: ScrapingModule, completion: @escaping (Bool, URL?) -> Void) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(false, nil)
            return
        }
        
        let folderURL = documentsDirectory.appendingPathComponent(title + "-" + module.metadata.sourceName)
        if (!FileManager.default.fileExists(atPath: folderURL.path)) {
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                Logger.shared.log("Error creating folder: \(error)")
                completion(false, nil)
                return
            }
        }
        
        let outputFileName = "\(title)_Episode\(episode)_\(module.metadata.sourceName).mp4"
        let outputFileURL = folderURL.appendingPathComponent(outputFileName)
        
        let fileExtension = url.pathExtension.lowercased()
        
        if fileExtension == "mp4" {
            NotificationCenter.default.post(name: .DownloadManagerStatusUpdate, object: nil, userInfo: [
                "title": title,
                "episode": episode,
                "type": "mp4",
                "status": "Downloading",
                "progress": 0.0
            ])
            
            let task = URLSession.custom.downloadTask(with: url) { tempLocalURL, response, error in
                if let tempLocalURL = tempLocalURL {
                    do {
                        try FileManager.default.moveItem(at: tempLocalURL, to: outputFileURL)
                        NotificationCenter.default.post(name: .DownloadManagerStatusUpdate, object: nil, userInfo: [
                            "title": title,
                            "episode": episode,
                            "type": "mp4",
                            "status": "Completed",
                            "progress": 1.0
                        ])
                        DispatchQueue.main.async {
                            Logger.shared.log("Download successful: \(outputFileURL)")
                            completion(true, outputFileURL)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            Logger.shared.log("Download failed: \(error)")
                            completion(false, nil)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        Logger.shared.log("Download failed: \(error?.localizedDescription ?? "Unknown error")")
                        completion(false, nil)
                    }
                }
            }
            task.resume()
        } else if fileExtension == "m3u8" {
            let conversionKey = "\(title)_\(episode)_\(module.metadata.sourceName)"
            activeConversions[conversionKey] = true
            
            if UIApplication.shared.applicationState != .active && backgroundTaskIdentifier == .invalid {
                backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
                    self?.endBackgroundTask()
                }
            }
            
            DispatchQueue.global(qos: .background).async {
                NotificationCenter.default.post(name: .DownloadManagerStatusUpdate, object: nil, userInfo: [
                    "title": title,
                    "episode": episode,
                    "type": "hls",
                    "status": "Converting",
                    "progress": 0.0
                ])
                
                let processorCount = ProcessInfo.processInfo.processorCount
                let physicalMemory = ProcessInfo.processInfo.physicalMemory / (1024 * 1024)
                
                var ffmpegCommand = ["ffmpeg", "-y"]
                
                ffmpegCommand.append(contentsOf: ["-protocol_whitelist", "file,http,https,tcp,tls"])
                
                ffmpegCommand.append(contentsOf: ["-fflags", "+genpts"])
                ffmpegCommand.append(contentsOf: ["-reconnect", "1", "-reconnect_streamed", "1", "-reconnect_delay_max", "5"])
                ffmpegCommand.append(contentsOf: ["-headers", "Referer: \(module.metadata.baseUrl)\nOrigin: \(module.metadata.baseUrl)"])
                
                let multiThreads = UserDefaults.standard.bool(forKey: "multiThreads")
                if multiThreads {
                    let threadCount = max(2, processorCount - 1)
                    ffmpegCommand.append(contentsOf: ["-threads", "\(threadCount)"])
                } else {
                    ffmpegCommand.append(contentsOf: ["-threads", "2"])
                }
                
                let bufferSize = min(32, max(8, Int(physicalMemory) / 256))
                ffmpegCommand.append(contentsOf: ["-bufsize", "\(bufferSize)M"])
                ffmpegCommand.append(contentsOf: ["-i", url.absoluteString])
                
                if let subtitleURL = subtitleURL {
                    do {
                        let subtitleData = try Data(contentsOf: subtitleURL)
                        let subtitleFileExtension = subtitleURL.pathExtension.lowercased()
                        if subtitleFileExtension != "srt" && subtitleFileExtension != "vtt" {
                            Logger.shared.log("Unsupported subtitle format: \(subtitleFileExtension)")
                        }
                        let subtitleFileName = "\(title)_Episode\(episode).\(subtitleFileExtension)"
                        let subtitleLocalURL = folderURL.appendingPathComponent(subtitleFileName)
                        try subtitleData.write(to: subtitleLocalURL)
                        ffmpegCommand.append(contentsOf: ["-i", subtitleLocalURL.path])
                        
                        ffmpegCommand.append(contentsOf: [
                            "-c:v", "copy",
                            "-c:a", "copy",
                            "-c:s", "mov_text",
                            "-disposition:s:0", "default+forced",
                            "-metadata:s:s:0", "handler_name=English",
                            "-metadata:s:s:0", "language=eng"
                        ])
                        
                        ffmpegCommand.append(outputFileURL.path)
                    } catch {
                        Logger.shared.log("Subtitle download failed: \(error)")
                        ffmpegCommand.append(contentsOf: ["-c:v", "copy", "-c:a", "copy"])
                        ffmpegCommand.append(contentsOf: ["-movflags", "+faststart"])
                        ffmpegCommand.append(outputFileURL.path)
                    }
                } else {
                    ffmpegCommand.append(contentsOf: ["-c:v", "copy", "-c:a", "copy"])
                    ffmpegCommand.append(contentsOf: ["-movflags", "+faststart"])
                    ffmpegCommand.append(outputFileURL.path)
                }
                Logger.shared.log("FFmpeg command: \(ffmpegCommand.joined(separator: " "))", type: "Debug")
                
                NotificationCenter.default.post(name: .DownloadManagerStatusUpdate, object: nil, userInfo: [
                    "title": title,
                    "episode": episode,
                    "type": "hls",
                    "status": "Converting",
                    "progress": 0.5
                ])
                
                let success = ffmpeg(ffmpegCommand)
                DispatchQueue.main.async { [weak self] in
                    if success == 0 {
                        NotificationCenter.default.post(name: .DownloadManagerStatusUpdate, object: nil, userInfo: [
                            "title": title,
                            "episode": episode,
                            "type": "hls",
                            "status": "Completed",
                            "progress": 1.0
                        ])
                        Logger.shared.log("Conversion successful: \(outputFileURL)")
                        completion(true, outputFileURL)
                    } else {
                        Logger.shared.log("Conversion failed")
                        completion(false, nil)
                    }
                    
                    self?.activeConversions[conversionKey] = nil
                    
                    if self?.activeConversions.isEmpty ?? true {
                        self?.endBackgroundTask()
                    }
                }
            }
        } else {
            Logger.shared.log("Unsupported file type: \(fileExtension)")
            completion(false, nil)
        }
    }
}
