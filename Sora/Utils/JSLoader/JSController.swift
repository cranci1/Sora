//
//  JSController.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import JavaScriptCore
import Foundation
import SwiftUI
import AVKit
import AVFoundation

// Use ScrapingModule from Modules.swift as Module
typealias Module = ScrapingModule

class JSController: NSObject, ObservableObject {
    // Shared instance that can be used across the app
    static let shared = JSController()
    
    var context: JSContext
    
    // Downloaded assets storage
    @Published var savedAssets: [DownloadedAsset] = []
    @Published var activeDownloads: [JSActiveDownload] = []
    
    // Tracking map for download tasks
    var activeDownloadMap: [URLSessionTask: UUID] = [:]
    
    // Download queue management
    @Published var downloadQueue: [JSActiveDownload] = []
    var isProcessingQueue: Bool = false
    var maxConcurrentDownloads: Int {
        UserDefaults.standard.object(forKey: "maxConcurrentDownloads") as? Int ?? 3
    }
    
    // Track downloads that have been cancelled to prevent completion processing
    var cancelledDownloadIDs: Set<UUID> = []
    
    // Download session
    var downloadURLSession: AVAssetDownloadURLSession?
    
    // For MP4 download progress tracking
    var mp4ProgressObservations: [UUID: NSKeyValueObservation]?
    
    // For storing custom URLSessions used for MP4 downloads
    var mp4CustomSessions: [UUID: URLSession]?
    
    override init() {
        self.context = JSContext()
        super.init()
        setupContext()
        loadSavedAssets()
    }
    
    func setupContext() {
        context.setupJavaScriptEnvironment()
        setupDownloadSession()
    }
    
    // Setup download functionality separately from general context setup
    private func setupDownloadSession() {
        // Only initialize download session if it doesn't exist already
        if downloadURLSession == nil {
            initializeDownloadSession()
            setupDownloadFunction()
        }
    }
    
    func loadScript(_ script: String) {
        context = JSContext()
        // Only set up the JavaScript environment without reinitializing the download session
        context.setupJavaScriptEnvironment()
        context.evaluateScript(script)
        if let exception = context.exception {
            Logger.shared.log("Error loading script: \(exception)", type: "Error")
        }
    }
    
    // MARK: - Download Settings
    
    /// Updates the maximum number of concurrent downloads and processes the queue if new slots are available
    func updateMaxConcurrentDownloads(_ newLimit: Int) {
        print("Updating max concurrent downloads from \(maxConcurrentDownloads) to \(newLimit)")
        
        // The maxConcurrentDownloads computed property will automatically use the new UserDefaults value
        // If the new limit is higher and we have queued downloads, process the queue
        if !downloadQueue.isEmpty && !isProcessingQueue {
            print("Processing download queue due to increased concurrent limit. Queue has \(downloadQueue.count) items.")
            
            // Force UI update before processing queue
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.objectWillChange.send()
                
                // Process the queue with a slight delay to ensure UI is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.processDownloadQueue()
                }
            }
        } else {
            print("No queued downloads to process or queue is already being processed")
        }
    }
    
    // MARK: - Stream URL Functions - Convenience methods
    
    func fetchStreamUrl(episodeUrl: String, module: Module, completion: @escaping ((streams: [String]?, subtitles: [String]?)) -> Void) {
        // Implementation for the main fetchStreamUrl method
    }
    
    func fetchStreamUrlJS(episodeUrl: String, module: Module, completion: @escaping ((streams: [String]?, subtitles: [String]?)) -> Void) {
        // Implementation for the JS based stream URL fetching
    }
    
    func fetchStreamUrlJSSecond(episodeUrl: String, module: Module, completion: @escaping ((streams: [String]?, subtitles: [String]?)) -> Void) {
        // Implementation for the secondary JS based stream URL fetching
    }
    
    // MARK: - Header Management
    // Header management functions are implemented in JSController-HeaderManager.swift extension file
}
