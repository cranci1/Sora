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

typealias Module = ScrapingModule

class JSController: NSObject, ObservableObject {
    static let shared = JSController()
    
    var context: JSContext
    
    @Published var savedAssets: [DownloadedAsset] = []
    @Published var activeDownloads: [JSActiveDownload] = []
    var activeDownloadMap: [URLSessionTask: UUID] = [:]
    @Published var downloadQueue: [JSActiveDownload] = []
    var isProcessingQueue: Bool = false
    
    var maxConcurrentDownloads: Int {
        UserDefaults.standard.object(forKey: "maxConcurrentDownloads") as? Int ?? 3
    }
    
    var cancelledDownloadIDs: Set<UUID> = []
    var downloadURLSession: AVAssetDownloadURLSession?
    var mp4ProgressObservations: [UUID: NSKeyValueObservation]?
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
    
    private func setupDownloadSession() {
        if downloadURLSession == nil {
            initializeDownloadSession()
            setupDownloadFunction()
        }
    }
    
    func loadScript(_ script: String) {
        context = JSContext()
        context.setupJavaScriptEnvironment()
        context.evaluateScript(script)
        if let exception = context.exception {
            Logger.shared.log("Error loading script: \(exception)", type: "Error")
        }
    }
    
    func updateMaxConcurrentDownloads(_ newLimit: Int) {
        print("Updating max concurrent downloads from \(maxConcurrentDownloads) to \(newLimit)")
        if !downloadQueue.isEmpty && !isProcessingQueue {
            print("Processing download queue due to increased concurrent limit. Queue has \(downloadQueue.count) items.")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.objectWillChange.send()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.processDownloadQueue()
                }
            }
        } else {
            print("No queued downloads to process or queue is already being processed")
        }
    }
}


