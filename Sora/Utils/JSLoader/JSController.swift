//
//  JSController.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import JavaScriptCore

class JSController: ObservableObject {
    var context: JSContext

    init() {
        self.context = JSContext()
        setupContext()
    }

    func setupContext() {
        context.setupJavaScriptEnvironment()
    }

    func loadScript(_ script: String) {
        context = JSContext()
        setupContext()
        context.evaluateScript(script)
        if let exception = context.exception {
            Logger.shared.log("Error loading script: \(exception)", type: .error)
        }
    }
}
