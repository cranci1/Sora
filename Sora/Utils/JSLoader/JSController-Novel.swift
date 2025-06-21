//
//  JSController-Novel.swift
//  Sora
//
//  Created by paul on 20/06/25.
//

import Foundation
import JavaScriptCore

enum JSError: Error {
    case moduleNotFound
    case invalidResponse
    case emptyContent
    case redirectError
    case jsException(String)
    
    var localizedDescription: String {
        switch self {
        case .moduleNotFound:
            return "Module not found"
        case .invalidResponse:
            return "Invalid response from server"
        case .emptyContent:
            return "No content received"
        case .redirectError:
            return "Redirect error occurred"
        case .jsException(let message):
            return "JavaScript error: \(message)"
        }
    }
}

extension JSController {
    @MainActor
    func extractChapters(moduleId: String, href: String) async throws -> [[String: Any]] {
        guard let module = ModuleManager().modules.first(where: { $0.id.uuidString == moduleId }) else {
            throw JSError.moduleNotFound
        }
        
        return await withCheckedContinuation { (continuation: CheckedContinuation<[[String: Any]], Never>) in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                guard let extractChaptersFunction = self.context.objectForKeyedSubscript("extractChapters") else {
                    Logger.shared.log("extractChapters: function not found", type: "Error")
                    continuation.resume(returning: [])
                    return
                }
                let result = extractChaptersFunction.call(withArguments: [href])
                if result?.isUndefined == true || result == nil {
                    Logger.shared.log("extractChapters: result is undefined or nil", type: "Error")
                    continuation.resume(returning: [])
                    return
                }
                if let result = result, result.hasProperty("then") {
                    let group = DispatchGroup()
                    group.enter()
                    var chaptersArr: [[String: Any]] = []
                    let thenBlock: @convention(block) (JSValue) -> Void = { jsValue in
                        Logger.shared.log("extractChapters thenBlock: \(jsValue)", type: "Debug")
                        if let arr = jsValue.toArray() as? [[String: Any]] {
                            Logger.shared.log("extractChapters: parsed as array, count = \(arr.count)", type: "Debug")
                            chaptersArr = arr
                        } else if let jsonString = jsValue.toString(), let data = jsonString.data(using: .utf8) {
                            do {
                                if let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                                    Logger.shared.log("extractChapters: parsed as JSON string, count = \(arr.count)", type: "Debug")
                                    chaptersArr = arr
                                } else {
                                    Logger.shared.log("extractChapters: JSON string did not parse to array", type: "Error")
                                }
                            } catch {
                                Logger.shared.log("JSON parsing error of extractChapters: \(error)", type: "Error")
                            }
                        } else {
                            Logger.shared.log("extractChapters: could not parse result", type: "Error")
                        }
                        group.leave()
                    }
                    let catchBlock: @convention(block) (JSValue) -> Void = { jsValue in
                        Logger.shared.log("extractChapters catchBlock: \(jsValue)", type: "Error")
                        group.leave()
                    }
                    result.invokeMethod("then", withArguments: [thenBlock])
                    result.invokeMethod("catch", withArguments: [catchBlock])
                    group.notify(queue: .main) {
                        continuation.resume(returning: chaptersArr)
                    }
                } else {
                    if let arr = result?.toArray() as? [[String: Any]] {
                        Logger.shared.log("extractChapters: direct array, count = \(arr.count)", type: "Debug")
                        continuation.resume(returning: arr)
                    } else if let jsonString = result?.toString(), let data = jsonString.data(using: .utf8) {
                        do {
                            if let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                                Logger.shared.log("extractChapters: direct JSON string, count = \(arr.count)", type: "Debug")
                                continuation.resume(returning: arr)
                            } else {
                                Logger.shared.log("extractChapters: direct JSON string did not parse to array", type: "Error")
                                continuation.resume(returning: [])
                            }
                        } catch {
                            Logger.shared.log("JSON parsing error of extractChapters: \(error)", type: "Error")
                            continuation.resume(returning: [])
                        }
                    } else {
                        Logger.shared.log("extractChapters: could not parse direct result", type: "Error")
                        continuation.resume(returning: [])
                    }
                }
            }
        }
    }
    
    @MainActor
    func extractText(moduleId: String, href: String) async throws -> String {
        guard let module = ModuleManager().modules.first(where: { $0.id.uuidString == moduleId }) else {
            throw JSError.moduleNotFound
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: JSError.invalidResponse)
                    return
                }
                
                let function = self.context.objectForKeyedSubscript("extractText")
                let result = function?.call(withArguments: [href])
                
                if let exception = self.context.exception {
                    Logger.shared.log("Error extracting text: \(exception)", type: "Error")
                }
                
                if let result = result, result.hasProperty("then") {
                    let group = DispatchGroup()
                    group.enter()
                    var extractedText = ""
                    var extractError: Error? = nil
                    
                    let thenBlock: @convention(block) (JSValue) -> Void = { jsValue in
                        Logger.shared.log("extractText thenBlock: received value", type: "Debug")
                        if let text = jsValue.toString(), !text.isEmpty {
                            Logger.shared.log("extractText: successfully extracted text", type: "Debug")
                            extractedText = text
                        } else {
                            extractError = JSError.emptyContent
                        }
                        group.leave()
                    }
                    
                    let catchBlock: @convention(block) (JSValue) -> Void = { jsValue in
                        Logger.shared.log("extractText catchBlock: \(jsValue)", type: "Error")
                        if extractedText.isEmpty { 
                            extractError = JSError.jsException(jsValue.toString() ?? "Unknown error")
                        }
                        group.leave()
                    }
                    
                    result.invokeMethod("then", withArguments: [thenBlock])
                    result.invokeMethod("catch", withArguments: [catchBlock])
                    
                    group.notify(queue: .main) {
                        if !extractedText.isEmpty {
                            continuation.resume(returning: extractedText)
                        } else if let error = extractError {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(throwing: JSError.emptyContent)
                        }
                    }
                } else {
                    if let text = result?.toString(), !text.isEmpty {
                        Logger.shared.log("extractText: direct string result", type: "Debug")
                        continuation.resume(returning: text)
                    } else {
                        Logger.shared.log("extractText: could not parse direct result", type: "Error")
                        continuation.resume(throwing: JSError.emptyContent)
                    }
                }
            }
        }
    }
} 