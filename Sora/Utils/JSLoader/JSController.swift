//
//  JSController.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import JavaScriptCore
import Foundation
import SwiftUI

// Use ScrapingModule from Modules.swift as Module
typealias Module = ScrapingModule

class JSController: NSObject, ObservableObject {
    var context: JSContext
    
    // Downloaded assets storage
    @Published var savedAssets: [DownloadedAsset] = []
    @Published var activeDownloads: [ActiveDownload] = []
    
    override init() {
        self.context = JSContext()
        super.init()
        setupContext()
        loadSavedAssets()
    }
    
    func setupContext() {
        context.setupJavaScriptEnvironment()
        initializeDownloadSession()
        setupDownloadFunction()
    }
    
    func loadScript(_ script: String) {
        context = JSContext()
        setupContext()
        context.evaluateScript(script)
        if let exception = context.exception {
            Logger.shared.log("Error loading script: \(exception)", type: "Error")
        }
    }
    
    // MARK: - Download Session
    
    private func initializeDownloadSession() {
        // Initialize URL session for downloads
        // Implementation in JSController-Downloads.swift
    }
    
    private func setupDownloadFunction() {
        // Set up JavaScript download function
        // Implementation in JSController-Downloads.swift
    }
    
    // MARK: - Asset Management
    
    private func loadSavedAssets() {
        // Load previously saved assets from UserDefaults or FileManager
        // (This would typically be in JSController-Downloads.swift)
        
        // Placeholder implementation to prevent compiler errors
        self.savedAssets = []
    }
    
    func deleteAsset(_ asset: DownloadedAsset) {
        // Delete an asset from savedAssets and from disk
        // Implementation in JSController-Downloads.swift
    }
    
    // MARK: - Stream URL Functions - Convenience methods
    
    func fetchStreamUrl(episodeUrl: String, module: Module, completion: @escaping ((streams: [String]?, subtitles: [String]?)) -> Void) {
        fetchStreamUrl(episodeUrl: episodeUrl, softsub: false, module: module, completion: completion)
    }
    
    func fetchStreamUrlJS(episodeUrl: String, module: Module, completion: @escaping ((streams: [String]?, subtitles: [String]?)) -> Void) {
        fetchStreamUrlJS(episodeUrl: episodeUrl, softsub: false, module: module, completion: completion)
    }
    
    func fetchStreamUrlJSSecond(episodeUrl: String, module: Module, completion: @escaping ((streams: [String]?, subtitles: [String]?)) -> Void) {
        fetchStreamUrlJSSecond(episodeUrl: episodeUrl, softsub: false, module: module, completion: completion)
    }
    
    // MARK: - Header Management
    // Header management functions are implemented in JSController-HeaderManager.swift extension file
}
