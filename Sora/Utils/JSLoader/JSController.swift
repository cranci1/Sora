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
        // Inject async Promise bridge for extractChapters with debug logging
        let asyncChaptersHelper = """
        function extractChaptersWithCallback(href, callback) {
            try {
                console.log('[JS] extractChaptersWithCallback called with href:', href);
                var result = extractChapters(href);
                if (result && typeof result.then === 'function') {
                    result.then(function(arr) {
                        console.log('[JS] extractChaptersWithCallback Promise resolved, arr.length:', arr && arr.length);
                        callback(arr);
                    }).catch(function(e) {
                        console.log('[JS] extractChaptersWithCallback Promise rejected:', e);
                        callback([]);
                    });
                } else {
                    console.log('[JS] extractChaptersWithCallback result is not a Promise:', result);
                    callback(result);
                }
            } catch (e) {
                console.log('[JS] extractChaptersWithCallback threw:', e);
                callback([]);
            }
        }
        """
        context.evaluateScript(asyncChaptersHelper)
        // Print JS exceptions to Xcode console
        context.exceptionHandler = { context, exception in
            print("[JS Exception]", exception?.toString() ?? "unknown")
        }
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
        if !downloadQueue.isEmpty && !isProcessingQueue {
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.objectWillChange.send()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.processDownloadQueue()
                }
            }
        } else {
            Logger.shared.log("No queued downloads to process or queue is already being processed")
        }
    }
}


