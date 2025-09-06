//
//  NetworkFetch.swift
//  Sora
//
//  Created by paul on 17/08/2025.
//

import WebKit
import JavaScriptCore

struct NetworkFetchOptions {
    let timeoutSeconds: Int
    let headers: [String: String]
    let cutoff: String?
    let returnHTML: Bool
    let clickSelectors: [String]
    let waitForSelectors: [String]
    let maxWaitTime: Int
    
    init(
        timeoutSeconds: Int = 10,
        headers: [String: String] = [:],
        cutoff: String? = nil,
        returnHTML: Bool = false,
        clickSelectors: [String] = [],
        waitForSelectors: [String] = [],
        maxWaitTime: Int = 5
    ) {
        self.timeoutSeconds = timeoutSeconds
        self.headers = headers
        self.cutoff = cutoff
        self.returnHTML = returnHTML
        self.clickSelectors = clickSelectors
        self.waitForSelectors = waitForSelectors
        self.maxWaitTime = maxWaitTime
    }
}

extension JSContext {
    func setupNetworkFetch() {
        let networkFetchNativeFunction: @convention(block) (String, JSValue?, JSValue, JSValue) -> Void = { urlString, optionsValue, resolve, reject in
            DispatchQueue.main.async {
                var options = NetworkFetchOptions()
                
                if let optionsDict = optionsValue?.toDictionary() {
                    let timeoutSeconds = optionsDict["timeoutSeconds"] as? Int ?? 10
                    let headers = optionsDict["headers"] as? [String: String] ?? [:]
                    let cutoff = optionsDict["cutoff"] as? String
                    let returnHTML = optionsDict["returnHTML"] as? Bool ?? false
                    let clickSelectors = optionsDict["clickSelectors"] as? [String] ?? []
                    let waitForSelectors = optionsDict["waitForSelectors"] as? [String] ?? []
                    let maxWaitTime = optionsDict["maxWaitTime"] as? Int ?? 5
                    
                    options = NetworkFetchOptions(
                        timeoutSeconds: timeoutSeconds,
                        headers: headers,
                        cutoff: cutoff,
                        returnHTML: returnHTML,
                        clickSelectors: clickSelectors,
                        waitForSelectors: waitForSelectors,
                        maxWaitTime: maxWaitTime
                    )
                }
                
                NetworkFetchManager.shared.performNetworkFetch(
                    urlString: urlString,
                    options: options,
                    resolve: resolve,
                    reject: reject
                )
            }
        }
        
        self.setObject(networkFetchNativeFunction, forKeyedSubscript: "networkFetchNative" as NSString)
        
        let networkFetchDefinition = """
            function networkFetch(url, options = {}) {
                if (typeof options === 'number') {
                    const timeoutSeconds = options;
                    const headers = arguments[2] || {};
                    const cutoff = arguments[3] || null;
                    options = { timeoutSeconds, headers, cutoff };
                }
                
                const finalOptions = {
                    timeoutSeconds: options.timeoutSeconds || 10,
                    headers: options.headers || {},
                    cutoff: options.cutoff || null,
                    returnHTML: options.returnHTML || false,
                    clickSelectors: options.clickSelectors || [],
                    waitForSelectors: options.waitForSelectors || [],
                    maxWaitTime: options.maxWaitTime || 5
                };
                
                return new Promise(function(resolve, reject) {
                    networkFetchNative(url, finalOptions, function(result) {
                        resolve({
                            url: result.originalUrl,
                            requests: result.requests,
                            html: result.html || null,
                            success: result.success,
                            error: result.error || null,
                            totalRequests: result.requests.length,
                            cutoffTriggered: result.cutoffTriggered || false,
                            cutoffUrl: result.cutoffUrl || null,
                            htmlCaptured: result.htmlCaptured || false,
                            elementsClicked: result.elementsClicked || [],
                            waitResults: result.waitResults || {}
                        });
                    }, reject);
                });
            }
            
            function networkFetchWithHTML(url, timeoutSeconds = 10) {
                return networkFetch(url, {
                    timeoutSeconds: timeoutSeconds,
                    returnHTML: true
                });
            }
            
            function networkFetchWithCutoff(url, cutoff, timeoutSeconds = 10) {
                return networkFetch(url, {
                    timeoutSeconds: timeoutSeconds,
                    cutoff: cutoff
                });
            }
            
            function networkFetchWithClicks(url, clickSelectors, options = {}) {
                return networkFetch(url, {
                    timeoutSeconds: options.timeoutSeconds || 10,
                    headers: options.headers || {},
                    cutoff: options.cutoff || null,
                    returnHTML: options.returnHTML || false,
                    clickSelectors: Array.isArray(clickSelectors) ? clickSelectors : [clickSelectors],
                    waitForSelectors: options.waitForSelectors || [],
                    maxWaitTime: options.maxWaitTime || 5
                });
            }
            
            function networkFetchWithWaitAndClick(url, waitForSelectors, clickSelectors, options = {}) {
                return networkFetch(url, {
                    timeoutSeconds: options.timeoutSeconds || 10,
                    headers: options.headers || {},
                    cutoff: options.cutoff || null,
                    returnHTML: options.returnHTML || false,
                    clickSelectors: Array.isArray(clickSelectors) ? clickSelectors : [clickSelectors],
                    waitForSelectors: Array.isArray(waitForSelectors) ? waitForSelectors : [waitForSelectors],
                    maxWaitTime: options.maxWaitTime || 5
                });
            }
            """
        
        self.evaluateScript(networkFetchDefinition)
    }
}

class NetworkFetchManager: NSObject, ObservableObject {
    static let shared = NetworkFetchManager()
    
    private var activeMonitors: [String: NetworkFetchMonitor] = [:]
    
    private override init() {
        super.init()
    }
    
    func performNetworkFetch(urlString: String, options: NetworkFetchOptions, resolve: JSValue, reject: JSValue) {
        Logger.shared.log("NetworkFetchManager: Starting fetch for \(urlString) with options: returnHTML=\(options.returnHTML), clicks=\(options.clickSelectors), waitFor=\(options.waitForSelectors)", type: "Debug")
        
        let monitorId = UUID().uuidString
        let monitor = NetworkFetchMonitor()
        activeMonitors[monitorId] = monitor
        
        monitor.startMonitoring(
            urlString: urlString,
            options: options
        ) { [weak self] result in
            Logger.shared.log("NetworkFetchManager: Fetch completed for \(urlString)", type: "Debug")
            
            self?.activeMonitors.removeValue(forKey: monitorId)
            
            DispatchQueue.main.async {
                if !resolve.isUndefined {
                    Logger.shared.log("NetworkFetchManager: Calling resolve with result", type: "Debug")
                    resolve.call(withArguments: [result])
                } else {
                    Logger.shared.log("NetworkFetchManager: Resolve callback is undefined!", type: "Error")
                }
            }
        }
    }
}

class NetworkFetchMonitor: NSObject, ObservableObject {
    private var webView: WKWebView?
    private var completionHandler: (([String: Any]) -> Void)?
    private var timer: Timer?
    private var options: NetworkFetchOptions?
    private var elementsClicked: [String] = []
    private var waitResults: [String: Bool] = [:]
    
    @Published private(set) var networkRequests: [String] = []
    @Published private(set) var statusMessage = "Initializing..."
    @Published private(set) var cutoffTriggered = false
    @Published private(set) var cutoffUrl: String? = nil
    @Published private(set) var htmlContent: String? = nil
    @Published private(set) var htmlCaptured = false
    
    func startMonitoring(urlString: String, options: NetworkFetchOptions, completion: @escaping ([String: Any]) -> Void) {
        self.options = options
        completionHandler = completion
        networkRequests.removeAll()
        cutoffTriggered = false
        cutoffUrl = nil
        htmlContent = nil
        htmlCaptured = false
        elementsClicked.removeAll()
        waitResults.removeAll()
        
        var statusParts = ["Loading URL for \(options.timeoutSeconds) seconds"]
        if !options.waitForSelectors.isEmpty {
            statusParts.append("waiting for elements")
        }
        if !options.clickSelectors.isEmpty {
            statusParts.append("will click elements")
        }
        if options.returnHTML {
            statusParts.append("will capture HTML")
        }
        statusMessage = statusParts.joined(separator: ", ") + "..."
        
        guard let url = URL(string: urlString) else {
            completion([
                "originalUrl": urlString,
                "requests": [],
                "html": NSNull(),
                "success": false,
                "error": "Invalid URL format",
                "htmlCaptured": false,
                "elementsClicked": [],
                "waitResults": [:]
            ])
            return
        }
        
        setupWebView()
        loadURL(url: url, headers: options.headers)
        
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(options.timeoutSeconds), repeats: false) { [weak self] _ in
            if options.returnHTML {
                self?.captureHTMLThenComplete()
            } else {
                self?.stopMonitoring(reason: "timeout")
            }
        }
        
        Logger.shared.log("NetworkFetch started for: \(urlString) (timeout: \(options.timeoutSeconds)s, returnHTML: \(options.returnHTML), clicks: \(options.clickSelectors), waitFor: \(options.waitForSelectors))", type: "Debug")
    }
    
    private func captureHTMLThenComplete() {
        guard let webView = webView, let options = options, options.returnHTML else {
            stopMonitoring(reason: "timeout")
            return
        }
        
        statusMessage = "Capturing HTML content before timeout..."
        Logger.shared.log("NetworkFetch: Capturing HTML at timeout", type: "Debug")
        
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            DispatchQueue.main.async {
                if let html = result as? String, error == nil {
                    self?.htmlContent = html
                    self?.htmlCaptured = true
                    Logger.shared.log("NetworkFetch: HTML captured successfully (\(html.count) characters)", type: "Debug")
                } else {
                    Logger.shared.log("NetworkFetch: Failed to capture HTML: \(error?.localizedDescription ?? "Unknown error")", type: "Error")
                }
                
                self?.stopMonitoring(reason: "timeout_with_html")
            }
        }
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let jsCode = """
        (function() {
            console.log('Advanced network interceptor loaded');
            
            Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
            Object.defineProperty(navigator, 'plugins', { get: () => [1, 2, 3, 4, 5] });
            Object.defineProperty(navigator, 'languages', { get: () => ['en-US', 'en'] });
            delete window.navigator.__proto__.webdriver;
            
            window.chrome = { runtime: {} };
            Object.defineProperty(navigator, 'permissions', { get: () => undefined });
            
            const originalFetch = window.fetch;
            const originalXHROpen = XMLHttpRequest.prototype.open;
            const originalXHRSend = XMLHttpRequest.prototype.send;
            
            window.fetch = function() {
                const url = arguments[0];
                const options = arguments[1] || {};
                
                try {
                    const fullUrl = new URL(url, window.location.href).href;
                    console.log('FETCH INTERCEPTED:', fullUrl);
                    window.webkit.messageHandlers.networkLogger.postMessage({
                        type: 'fetch',
                        url: fullUrl
                    });
                } catch(e) {
                    console.log('FETCH INTERCEPTED (fallback):', url);
                    window.webkit.messageHandlers.networkLogger.postMessage({
                        type: 'fetch',
                        url: url.toString()
                    });
                }
                return originalFetch.apply(this, arguments);
            };
            
            XMLHttpRequest.prototype.open = function() {
                const method = arguments[0];
                const url = arguments[1];
                
                try {
                    this._url = new URL(url, window.location.href).href;
                } catch(e) {
                    this._url = url;
                }
                
                console.log('XHR OPEN:', this._url);
                window.webkit.messageHandlers.networkLogger.postMessage({
                    type: 'xhr-open',
                    url: this._url
                });
                
                const self = this;
                const originalOnReadyStateChange = this.onreadystatechange;
                
                this.onreadystatechange = function() {
                    if (this.readyState === 4) {
                        if (this.responseURL) {
                            console.log('XHR RESPONSE URL:', this.responseURL);
                            window.webkit.messageHandlers.networkLogger.postMessage({
                                type: 'xhr-response',
                                url: this.responseURL
                            });
                        }
                        
                        try {
                            const responseText = this.responseText;
                            if (responseText) {
                                const urlRegex = /(https?:\\/\\/[^\\s"'<>]+\\.(m3u8|ts|mp4|webm|mkv))/gi;
                                const matches = responseText.match(urlRegex);
                                if (matches) {
                                    matches.forEach(function(match) {
                                        console.log('URL IN RESPONSE:', match);
                                        window.webkit.messageHandlers.networkLogger.postMessage({
                                            type: 'response-content',
                                            url: match
                                        });
                                    });
                                }
                            }
                        } catch(e) {
                            console.log('Response text check failed:', e);
                        }
                    }
                    
                    if (originalOnReadyStateChange) {
                        originalOnReadyStateChange.apply(this, arguments);
                    }
                };
                
                return originalXHROpen.apply(this, arguments);
            };
            
            XMLHttpRequest.prototype.send = function() {
                if (this._url) {
                    console.log('XHR SEND:', this._url);
                    window.webkit.messageHandlers.networkLogger.postMessage({
                        type: 'xhr-send',
                        url: this._url
                    });
                }
                return originalXHRSend.apply(this, arguments);
            };
            
            const originalWebSocket = window.WebSocket;
            window.WebSocket = function(url, protocols) {
                console.log('WEBSOCKET:', url);
                window.webkit.messageHandlers.networkLogger.postMessage({
                    type: 'websocket',
                    url: url
                });
                return new originalWebSocket(url, protocols);
            };
            
            const hookUrlProperties = function(obj, properties) {
                properties.forEach(function(prop) {
                    if (obj && obj.prototype) {
                        const descriptor = Object.getOwnPropertyDescriptor(obj.prototype, prop) || {};
                        const originalSetter = descriptor.set;
                        
                        if (originalSetter) {
                            Object.defineProperty(obj.prototype, prop, {
                                set: function(value) {
                                    if (typeof value === 'string' && (value.includes('http') || value.includes('.m3u8') || value.includes('.ts'))) {
                                        console.log('URL PROPERTY SET:', prop, value);
                                        window.webkit.messageHandlers.networkLogger.postMessage({
                                            type: 'property-set',
                                            url: value
                                        });
                                    }
                                    return originalSetter.call(this, value);
                                },
                                get: descriptor.get,
                                configurable: true
                            });
                        }
                    }
                });
            };
            
            hookUrlProperties(HTMLVideoElement, ['src']);
            hookUrlProperties(HTMLSourceElement, ['src']);
            hookUrlProperties(HTMLScriptElement, ['src']);
            hookUrlProperties(HTMLImageElement, ['src']);
            
            let jwHookAttempts = 0;
            const aggressiveJWHook = function() {
                jwHookAttempts++;
                console.log('JWPlayer hook attempt:', jwHookAttempts);
                
                if (window.jwplayer) {
                    console.log('JWPlayer detected!');
                    
                    const originalJWPlayer = window.jwplayer;
                    window.jwplayer = function(id) {
                        console.log('JWPlayer called with ID:', id);
                        const player = originalJWPlayer.apply(this, arguments);
                        
                        if (player && player.setup) {
                            const originalSetup = player.setup;
                            player.setup = function(config) {
                                console.log('JWPlayer setup config:', config);
                                
                                const extractUrls = function(obj, path = '') {
                                    if (!obj) return;
                                    
                                    if (typeof obj === 'string' && (obj.includes('http') || obj.includes('.m3u8') || obj.includes('.ts'))) {
                                        console.log('JWPlayer URL found at', path + ':', obj);
                                        window.webkit.messageHandlers.networkLogger.postMessage({
                                            type: 'jwplayer-config',
                                            url: obj
                                        });
                                    } else if (typeof obj === 'object' && obj !== null) {
                                        Object.keys(obj).forEach(function(key) {
                                            extractUrls(obj[key], path + '.' + key);
                                        });
                                    }
                                };
                                
                                extractUrls(config);
                                return originalSetup.call(this, config);
                            };
                        }
                        
                        return player;
                    };
                    
                    Object.keys(originalJWPlayer).forEach(function(key) {
                        window.jwplayer[key] = originalJWPlayer[key];
                    });
                }
                
                if (jwHookAttempts < 20) {
                    setTimeout(aggressiveJWHook, 200);
                }
            };
            
            aggressiveJWHook();
            
            window.waitForElementAndClick = function(waitSelectors, clickSelectors, maxWaitTime) {
                return new Promise(function(resolve) {
                    const results = {
                        waitResults: {},
                        clickResults: []
                    };
                    
                    waitSelectors.forEach(function(selector) {
                        results.waitResults[selector] = false;
                    });
                    
                    const startTime = Date.now();
                    const checkInterval = 100; 
                    
                    const checkAndClick = function() {
                        const elapsed = (Date.now() - startTime) / 1000;
                        
                        let allFound = waitSelectors.length === 0; 
                        
                        waitSelectors.forEach(function(selector) {
                            const element = document.querySelector(selector);
                            if (element && element.offsetParent !== null) { 
                                results.waitResults[selector] = true;
                                console.log('Element found and visible:', selector);
                            }
                        });
                        
                        allFound = waitSelectors.every(function(selector) {
                            return results.waitResults[selector];
                        });
                        
                        if (allFound || elapsed >= maxWaitTime) {
                            clickSelectors.forEach(function(selector) {
                                try {
                                    const elements = document.querySelectorAll(selector);
                                    let clicked = false;
                                    
                                    elements.forEach(function(element) {
                                        if (element && element.offsetParent !== null) {
                                            try {
                                                element.click();
                                                clicked = true;
                                                console.log('Successfully clicked:', selector);
                                            } catch(e1) {
                                                try {
                                                    const event = new MouseEvent('click', {
                                                        view: window,
                                                        bubbles: true,
                                                        cancelable: true
                                                    });
                                                    element.dispatchEvent(event);
                                                    clicked = true;
                                                    console.log('Successfully dispatched click:', selector);
                                                } catch(e2) {
                                                    console.log('Failed to click element:', selector, e2);
                                                }
                                            }
                                        }
                                    });
                                    
                                    results.clickResults.push({
                                        selector: selector,
                                        success: clicked,
                                        elementsFound: elements.length
                                    });
                                } catch(e) {
                                    console.log('Error clicking selector:', selector, e);
                                    results.clickResults.push({
                                        selector: selector,
                                        success: false,
                                        error: e.message
                                    });
                                }
                            });
                            
                            window.webkit.messageHandlers.networkLogger.postMessage({
                                type: 'click-results',
                                results: results
                            });
                            
                            resolve(results);
                        } else if (elapsed < maxWaitTime) {
                            setTimeout(checkAndClick, checkInterval);
                        }
                    };
                    
                    checkAndClick();
                });
            };
            
            const nuclearScan = function() {
                console.log('Nuclear scan initiated');
                
                Object.keys(window).forEach(function(key) {
                    try {
                        const value = window[key];
                        if (typeof value === 'string' && (value.includes('.m3u8') || value.includes('.ts') || (value.includes('http') && value.includes('.')))) {
                            console.log('Global URL found:', key, value);
                            window.webkit.messageHandlers.networkLogger.postMessage({
                                type: 'global-variable',
                                url: value
                            });
                        }
                    } catch(e) {
                    }
                });
                
                document.querySelectorAll('script').forEach(function(script) {
                    if (script.textContent) {
                        const urlRegex = /(https?:\\/\\/[^\\s"'<>]+\\.(m3u8|ts|mp4))/gi;
                        const matches = script.textContent.match(urlRegex);
                        if (matches) {
                            matches.forEach(function(match) {
                                console.log('URL in script:', match);
                                window.webkit.messageHandlers.networkLogger.postMessage({
                                    type: 'script-content',
                                    url: match
                                });
                            });
                        }
                    }
                });
            };
            
            setTimeout(nuclearScan, 500);
            setTimeout(nuclearScan, 1500);
            setTimeout(nuclearScan, 3000);
            
            console.log('Advanced interceptor setup complete');
        })();
        """
        
        let userScript = WKUserScript(source: jsCode, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(self, name: "networkLogger")
        
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), configuration: config)
        webView?.navigationDelegate = self
        
        webView?.customUserAgent = URLSession.randomUserAgent
    }
    
    private func loadURL(url: URL, headers: [String: String]) {
        guard let webView = webView else { return }
        
        addRequest(url.absoluteString)
        
        var request = URLRequest(url: url)
        
        request.setValue(URLSession.randomUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("upgrade-insecure-requests", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
            Logger.shared.log("Custom header set: \(key): \(value)", type: "Debug")
        }
        
        if request.value(forHTTPHeaderField: "Referer") == nil {
            let randomReferers = [
                "https://www.google.com/",
                "https://www.youtube.com/",
                "https://twitter.com/",
                "https://www.reddit.com/",
                "https://www.facebook.com/"
            ]
            let defaultReferer = randomReferers.randomElement() ?? "https://www.google.com/"
            request.setValue(defaultReferer, forHTTPHeaderField: "Referer")
        }
        
        webView.load(request)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.performCustomInteractions()
        }
        
        Logger.shared.log("Started loading: \(url.absoluteString)", type: "Debug")
    }
    
    private func performCustomInteractions() {
        guard let webView = webView, let options = options else { return }
        
        if !options.waitForSelectors.isEmpty || !options.clickSelectors.isEmpty {
            let waitSelectorsJS = options.waitForSelectors.map { "'\($0)'" }.joined(separator: ", ")
            let clickSelectorsJS = options.clickSelectors.map { "'\($0)'" }.joined(separator: ", ")
            
            let customInteractionJS = """
            window.waitForElementAndClick(
                [\(waitSelectorsJS)],
                [\(clickSelectorsJS)],
                \(options.maxWaitTime)
            ).then(function(results) {
                console.log('Custom interaction completed:', results);
            });
            """
            
            statusMessage = "Performing custom interactions..."
            Logger.shared.log("NetworkFetch: Starting custom interactions - wait for: \(options.waitForSelectors), click: \(options.clickSelectors)", type: "Debug")
            
            webView.evaluateJavaScript(customInteractionJS) { result, error in
                if let error = error {
                    Logger.shared.log("NetworkFetch: Custom interaction error: \(error)", type: "Error")
                } else {
                    Logger.shared.log("NetworkFetch: Custom interaction JavaScript executed successfully", type: "Debug")
                }
            }
        } else {
            simulateUserInteraction()
        }
    }
    
    private func simulateUserInteraction() {
        guard let webView = webView else { return }
        
        let jsInteraction = """
        setTimeout(function() {
            const playButtons = document.querySelectorAll('button, div, span, a');
            const filteredButtons = Array.from(playButtons).filter(function(el) {
                const text = el.textContent || el.innerText || '';
                const classes = el.className || '';
                const id = el.id || '';
                return text.toLowerCase().includes('play') || 
                       classes.toLowerCase().includes('play') ||
                       id.toLowerCase().includes('play') ||
                       el.getAttribute('aria-label')?.toLowerCase().includes('play');
            });
            
            filteredButtons.forEach(function(btn, index) {
                setTimeout(function() {
                    try {
                        btn.click();
                        console.log('Clicked play button:', btn);
                    } catch(e) {
                        console.log('Failed to click button:', e);
                    }
                }, index * 200);
            });
            
            window.scrollTo(0, document.body.scrollHeight / 2);
            setTimeout(function() {
                window.scrollTo(0, 0);
            }, 500);
            
            document.querySelectorAll('video').forEach(function(video) {
                if (video.play && typeof video.play === 'function') {
                    video.play().catch(function(e) {
                        console.log('Could not autoplay video:', e);
                    });
                }
            });
            
            if (window.jwplayer) {
                try {
                    const players = window.jwplayer().getInstances?.() || [];
                    players.forEach(function(player) {
                        if (player.play) {
                            player.play();
                        }
                    });
                } catch(e) {
                    console.log('JW Player interaction failed:', e);
                }
            }
            
            if (window.videojs) {
                try {
                    window.videojs.getAllPlayers?.().forEach(function(player) {
                        if (player.play) {
                            player.play();
                        }
                    });
                } catch(e) {
                    console.log('Video.js interaction failed:', e);
                }
            }
        }, 1000);
        """
        
        webView.evaluateJavaScript(jsInteraction) { result, error in
            if let error = error {
                Logger.shared.log("JavaScript interaction error: \(error)", type: "Error")
            }
        }
    }
    
    private func stopMonitoring(reason: String = "completed") {
        timer?.invalidate()
        timer = nil
        
        webView?.stopLoading()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "networkLogger")
        
        let result: [String: Any] = [
            "originalUrl": webView?.url?.absoluteString ?? "",
            "requests": networkRequests,
            "html": htmlContent as Any,
            "success": true,
            "cutoffTriggered": cutoffTriggered,
            "cutoffUrl": cutoffUrl as Any,
            "htmlCaptured": htmlCaptured,
            "elementsClicked": elementsClicked,
            "waitResults": waitResults
        ]
        
        webView = nil
        
        if cutoffTriggered {
            statusMessage = "Cutoff triggered! Found \(networkRequests.count) requests"
            Logger.shared.log("NetworkFetch stopped early due to cutoff: \(cutoffUrl ?? "unknown")", type: "Debug")
        } else if htmlCaptured {
            statusMessage = "HTML captured! Found \(networkRequests.count) requests, clicked \(elementsClicked.count) elements"
        } else {
            statusMessage = "Completed! Found \(networkRequests.count) requests, clicked \(elementsClicked.count) elements"
        }
        
        completionHandler?(result)
        completionHandler = nil
        
        Logger.shared.log("Monitoring stopped (\(reason)). Total requests: \(networkRequests.count), HTML captured: \(htmlCaptured), Elements clicked: \(elementsClicked.count)", type: "Debug")
    }
    
    private func addRequest(_ urlString: String) {
        DispatchQueue.main.async {
            if !self.networkRequests.contains(urlString) {
                self.networkRequests.append(urlString)
                Logger.shared.log("Captured: \(urlString)", type: "Debug")
                
                if let cutoff = self.options?.cutoff, !cutoff.isEmpty {
                    if urlString.lowercased().contains(cutoff.lowercased()) {
                        Logger.shared.log("Cutoff triggered by: \(urlString)", type: "Debug")
                        self.cutoffTriggered = true
                        self.cutoffUrl = urlString
                        self.stopMonitoring(reason: "cutoff")
                        return
                    }
                }
            }
        }
    }
}

extension NetworkFetchMonitor: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}
    
    private func webView(_ webView: WKNavigationAction, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            addRequest(url.absoluteString)
        }
        decisionHandler(.allow)
    }
}

extension NetworkFetchMonitor: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "networkLogger" {
            if let messageBody = message.body as? [String: Any] {
                if let url = messageBody["url"] as? String {
                    addRequest(url)
                } else if let type = messageBody["type"] as? String, type == "click-results" {
                    if let results = messageBody["results"] as? [String: Any] {
                        if let clickResults = results["clickResults"] as? [[String: Any]] {
                            DispatchQueue.main.async {
                                for clickResult in clickResults {
                                    if let selector = clickResult["selector"] as? String,
                                       let success = clickResult["success"] as? Bool, success {
                                        self.elementsClicked.append(selector)
                                        Logger.shared.log("NetworkFetch: Successfully clicked element: \(selector)", type: "Debug")
                                    }
                                }
                            }
                        }
                        
                        if let waitResults = results["waitResults"] as? [String: Bool] {
                            DispatchQueue.main.async {
                                self.waitResults = waitResults
                                Logger.shared.log("NetworkFetch: Wait results: \(waitResults)", type: "Debug")
                            }
                        }
                    }
                }
            }
        }
    }
}
