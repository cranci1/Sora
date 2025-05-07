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
    @Published var activeDownloads: [ActiveDownload] = []
    
    // Tracking map for download tasks
    var activeDownloadMap: [URLSessionTask: UUID] = [:]
    
    // Download session
    var downloadURLSession: AVAssetDownloadURLSession?
    
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
