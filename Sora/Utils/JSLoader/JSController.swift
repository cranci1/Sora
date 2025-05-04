//
//  JSController.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import JavaScriptCore

class JSController: NSObject, ObservableObject {
    var context: JSContext
    
    override init() {
        self.context = JSContext()
        super.init()
        setupContext()
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
}
