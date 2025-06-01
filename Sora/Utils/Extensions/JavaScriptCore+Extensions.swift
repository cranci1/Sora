//
//  JSContext+Extensions.swift
//  Sora
//
//  Created by Hamzo on 19/03/25.
//

import JavaScriptCore

extension JSContext {
    func setupConsoleLogging() {
        let consoleObject = JSValue(newObjectIn: self)
        
        let appInfoBridge = AppInfo()
        consoleObject?.setObject(appInfoBridge, forKeyedSubscript: "AppInfo" as NSString)
        
        let consoleLogFunction: @convention(block) (String) -> Void = { message in
            Logger.shared.log(message, type: "Debug")
        }
        consoleObject?.setObject(consoleLogFunction, forKeyedSubscript: "log" as NSString)
        
        let consoleErrorFunction: @convention(block) (String) -> Void = { message in
            Logger.shared.log(message, type: "Error")
        }
        consoleObject?.setObject(consoleErrorFunction, forKeyedSubscript: "error" as NSString)
        
        self.setObject(consoleObject, forKeyedSubscript: "console" as NSString)
        
        let logFunction: @convention(block) (String) -> Void = { message in
            Logger.shared.log("JavaScript log: \(message)", type: "Debug")
        }
        self.setObject(logFunction, forKeyedSubscript: "log" as NSString)
    }
    
    func setupNativeFetch() {
        let fetchNativeFunction: @convention(block) (String, [String: String]?, JSValue, JSValue) -> Void = { urlString, headers, resolve, reject in
            guard let url = URL(string: urlString) else {
                Logger.shared.log("Invalid URL", type: "Error")
                reject.call(withArguments: ["Invalid URL"])
                return
            }
            var request = URLRequest(url: url)
            if let headers = headers {
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            let task = URLSession.custom.dataTask(with: request) { data, _, error in
                if let error = error {
                    Logger.shared.log("Network error in fetchNativeFunction: \(error.localizedDescription)", type: "Error")
                    reject.call(withArguments: [error.localizedDescription])
                    return
                }
                guard let data = data else {
                    Logger.shared.log("No data in response", type: "Error")
                    reject.call(withArguments: ["No data"])
                    return
                }
                if let text = String(data: data, encoding: .utf8) {
                    resolve.call(withArguments: [text])
                } else {
                    Logger.shared.log("Unable to decode data to text", type: "Error")
                    reject.call(withArguments: ["Unable to decode data"])
                }
            }
            task.resume()
        }
        self.setObject(fetchNativeFunction, forKeyedSubscript: "fetchNative" as NSString)
        
        let fetchDefinition = """
                        function fetch(url, headers) {
                            return new Promise(function(resolve, reject) {
                                fetchNative(url, headers, resolve, reject);
                            });
                        }
                        """
        self.evaluateScript(fetchDefinition)
    }
    
    func setupFetchV2() {
        let fetchV2NativeFunction: @convention(block) (String, [String: String]?, String?, String?, ObjCBool,JSValue, JSValue) -> Void = { urlString, headers, method, body, redirect, resolve, reject in
            guard let url = URL(string: urlString) else {
                Logger.shared.log("Invalid URL", type: "Error")
                reject.call(withArguments: ["Invalid URL"])
                return
            }
            
            let httpMethod = method ?? "GET"
            var request = URLRequest(url: url)
            request.httpMethod = httpMethod
            
            Logger.shared.log("FetchV2 Request: URL=\(url), Method=\(httpMethod), Body=\(body ?? "nil")", type: "Debug")
            
            if httpMethod == "GET", let body = body, !body.isEmpty, body != "null", body != "undefined" {
                Logger.shared.log("GET request must not have a body", type: "Error")
                reject.call(withArguments: ["GET request must not have a body"])
                return
            }
            
            if httpMethod != "GET", let body = body, !body.isEmpty, body != "null", body != "undefined" {
                request.httpBody = body.data(using: .utf8)
            }
            
            
            if let headers = headers {
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            Logger.shared.log("Redirect value is \(redirect.boolValue)",type:"Error")
            let task = URLSession.fetchData(allowRedirects: redirect.boolValue).downloadTask(with: request) { tempFileURL, response, error in
                if let error = error {
                    Logger.shared.log("Network error in fetchV2NativeFunction: \(error.localizedDescription)", type: "Error")
                    DispatchQueue.main.async {
                        reject.call(withArguments: [error.localizedDescription])
                    }
                    return
                }
                
                guard let tempFileURL = tempFileURL else {
                    Logger.shared.log("No data in response", type: "Error")
                    DispatchQueue.main.async {
                        reject.call(withArguments: ["No data"])
                    }
                    return
                }
                
                var safeHeaders: [String: String] = [:]
                if let httpResponse = response as? HTTPURLResponse {
                    for (key, value) in httpResponse.allHeaderFields {
                        if let keyString = key as? String,
                           let valueString = value as? String {
                            safeHeaders[keyString] = valueString
                        }
                    }
                }
                
                var responseDict: [String: Any] = [
                    "status": (response as? HTTPURLResponse)?.statusCode ?? 0,
                    "headers": safeHeaders,
                    "body": ""
                ]
                
                do {
                    let data = try Data(contentsOf: tempFileURL)
                    
                    if data.count > 10_000_000 {
                        Logger.shared.log("Response exceeds maximum size", type: "Error")
                        DispatchQueue.main.async {
                            reject.call(withArguments: ["Response exceeds maximum size"])
                        }
                        return
                    }
                    
                    if let text = String(data: data, encoding: .utf8) {
                        responseDict["body"] = text
                        DispatchQueue.main.async {
                            resolve.call(withArguments: [responseDict])
                        }
                    } else {
                        Logger.shared.log("Unable to decode data to text", type: "Error")
                        DispatchQueue.main.async {
                            resolve.call(withArguments: [responseDict])
                        }
                    }
                    
                } catch {
                    Logger.shared.log("Error reading downloaded file: \(error.localizedDescription)", type: "Error")
                    DispatchQueue.main.async {
                        reject.call(withArguments: ["Error reading downloaded file"])
                    }
                }
            }
            task.resume()
        }
        
        
        self.setObject(fetchV2NativeFunction, forKeyedSubscript: "fetchV2Native" as NSString)
        
        let fetchv2Definition = """
                    function fetchv2(url, headers = {}, method = "GET", body = null, redirect = true ) {
                    
                    
                    var processedBody = null;
                    if(method != "GET")
                    {
                        // Ensure body is properly serialized
                        processedBody = (body && (typeof body === 'object')) ? JSON.stringify(body) : (body || null)
                    }
            
                        return new Promise(function(resolve, reject) {
                            fetchV2Native(url, headers, method, processedBody, redirect, function(rawText) {
                                const responseObj = {
                                    headers: rawText.headers,
                                    status: rawText.status,
                                    _data: rawText.body,
                                    text: function() {
                                        return Promise.resolve(this._data);
                                    },
                                    json: function() {
                                        try {
                                            return Promise.resolve(JSON.parse(this._data));
                                        } catch (e) {
                                            return Promise.reject("JSON parse error: " + e.message);
                                        }
                                    }
                                };
                                resolve(responseObj);
                            }, reject);
                        });
                    }
            
            """
        self.evaluateScript(fetchv2Definition)
    }
    
    func setupBase64Functions() {
        let btoaFunction: @convention(block) (String) -> String? = { data in
            guard let data = data.data(using: .utf8) else {
                Logger.shared.log("btoa: Failed to encode input as UTF-8", type: "Error")
                return nil
            }
            return data.base64EncodedString()
        }
        
        let atobFunction: @convention(block) (String) -> String? = { base64String in
            guard let data = Data(base64Encoded: base64String) else {
                Logger.shared.log("atob: Invalid base64 input", type: "Error")
                return nil
            }
            
            return String(data: data, encoding: .utf8)
        }
        
        self.setObject(btoaFunction, forKeyedSubscript: "btoa" as NSString)
        self.setObject(atobFunction, forKeyedSubscript: "atob" as NSString)
    }
    
    func setupJavaScriptEnvironment() {
        setupConsoleLogging()
        setupNativeFetch()
        setupFetchV2()
        setupBase64Functions()
    }
}
