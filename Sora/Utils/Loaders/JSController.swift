//
//  JSController.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//
import Foundation
import JavaScriptCore

class JSController: ObservableObject {
    private var context: JSContext
    
    init() {
        self.context = JSContext()
        setupContext()
    }
    
    private func setupContext() {
        let logFunction: @convention(block) (String) -> Void = { message in
            Logger.shared.log("JavaScript log: \(message)")
        }
        context.setObject(logFunction, forKeyedSubscript: "log" as NSString)
        
        let fetchNativeFunction: @convention(block) (String, JSValue, JSValue) -> Void = { urlString, resolve, reject in
            guard let url = URL(string: urlString) else {
                Logger.shared.log("Invalid URL")
                reject.call(withArguments: ["Invalid URL"])
                return
            }
            let task = URLSession.custom.dataTask(with: url) { data, _, error in
                if let error = error {
                    Logger.shared.log("\(url)")
                    Logger.shared.log("Network error in fetchNativeFunction: \(error.localizedDescription)")
                    reject.call(withArguments: [error.localizedDescription])
                    return
                }
                guard let data = data else {
                    Logger.shared.log("No data in response")
                    reject.call(withArguments: ["No data"])
                    return
                }
                if let text = String(data: data, encoding: .utf8) {
                    resolve.call(withArguments: [text])
                } else {
                    Logger.shared.log("Unable to decode data to text")
                    reject.call(withArguments: ["Unable to decode data"])
                }
            }
            task.resume()
        }
        context.setObject(fetchNativeFunction, forKeyedSubscript: "fetchNative" as NSString)
        
        let fetchDefinition = """
                    function fetch(url) {
                        return new Promise(function(resolve, reject) {
                            fetchNative(url, resolve, reject);
                        });
                    }
                    """
        context.evaluateScript(fetchDefinition)
    }
    
    func loadScript(_ script: String) {
        context = JSContext()
        setupContext()
        context.evaluateScript(script)
    }
    
    func fetchSearchResults(keyword: String, module: ScrapingModule, completion: @escaping ([SearchItem]) -> Void) {
        let searchUrl = module.metadata.searchBaseUrl.replacingOccurrences(of: "%s", with: keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        
        guard let url = URL(string: searchUrl) else {
            completion([])
            return
        }
        
        URLSession.custom.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.shared.log("Network error: \(error)")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                Logger.shared.log("Failed to decode HTML")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            if let parseFunction = self.context.objectForKeyedSubscript("searchResults"),
               let results = parseFunction.call(withArguments: [html]).toArray() as? [[String: String]] {
                let resultItems = results.map { item in
                    SearchItem(
                        title: item["title"] ?? "",
                        imageUrl: item["image"] ?? "",
                        href: item["href"] ?? ""
                    )
                }
                DispatchQueue.main.async {
                    completion(resultItems)
                }
            } else {
                Logger.shared.log("Failed to parse results")
                Logger.shared.log("Failed to parse results.", level: .error)
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
    
    func fetchDetails(url: String, completion: @escaping ([MediaItem], [EpisodeLink]) -> Void) {
        guard let url = URL(string: url) else {
            completion([], [])
            return
        }
        
        URLSession.custom.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.shared.log("Network error: \(error)")
                DispatchQueue.main.async { completion([], []) }
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                Logger.shared.log("Failed to decode HTML")
                DispatchQueue.main.async { completion([], []) }
                return
            }
            
            var resultItems: [MediaItem] = []
            var episodeLinks: [EpisodeLink] = []
            
            if let parseFunction = self.context.objectForKeyedSubscript("extractDetails"),
               let results = parseFunction.call(withArguments: [html]).toArray() as? [[String: String]] {
                resultItems = results.map { item in
                    MediaItem(
                        description: item["description"] ?? "",
                        aliases: item["aliases"] ?? "",
                        airdate: item["airdate"] ?? ""
                    )
                }
            } else {
                Logger.shared.log("Failed to parse results")
            }
            
            if let fetchEpisodesFunction = self.context.objectForKeyedSubscript("extractEpisodes"),
               let episodesResult = fetchEpisodesFunction.call(withArguments: [html]).toArray() as? [[String: String]] {
                for episodeData in episodesResult {
                    if let num = episodeData["number"], let link = episodeData["href"], let number = Int(num) {
                        episodeLinks.append(EpisodeLink(number: number, href: link))
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(resultItems, episodeLinks)
            }
        }.resume()
    }
    
    func fetchStreamUrl(episodeUrl: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: episodeUrl) else {
            completion(nil)
            return
        }
        
        URLSession.custom.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.shared.log("Network error: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                Logger.shared.log("Failed to decode HTML")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            if let parseFunction = self.context.objectForKeyedSubscript("extractStreamUrl"),
               let streamUrl = parseFunction.call(withArguments: [html]).toString() {
                DispatchQueue.main.async {
                    completion(streamUrl)
                }
                Logger.shared.log("Starting stream from: \(streamUrl)", level: .info)

            } else {
                Logger.shared.log("Failed to extract stream URL")
                DispatchQueue.main.async { completion(nil) }
                Logger.shared.log("Failed to extract stream URL.", level: .error)
            }
        }.resume()
    }
    
    func fetchJsSearchResults(keyword: String, module: ScrapingModule, completion: @escaping ([SearchItem]) -> Void) {
        if let exception = context.exception {
            Logger.shared.log("JavaScript exception: \(exception)")
            completion([])
            return
        }
        
        guard let searchResultsFunction = context.objectForKeyedSubscript("searchResults") else {
            Logger.shared.log("No JavaScript function searchResults found")
            completion([])
            return
        }
        
        let promiseValue = searchResultsFunction.call(withArguments: [keyword])
        guard let promise = promiseValue else {
            Logger.shared.log("searchResults did not return a Promise")
            completion([])
            return
        }
        
        let thenBlock: @convention(block) (JSValue) -> Void = { result in
            
            if let jsonString = result.toString(),
               let data = jsonString.data(using: .utf8) {
                do {
                    if let array = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        let resultItems = array.map { item -> SearchItem in
                            let title = item["title"] as? String ?? ""
                            let imageUrl = item["image"] as? String ?? "https://s4.anilist.co/file/anilistcdn/character/large/default.jpg"
                            let href = item["href"] as? String ?? ""
                            return SearchItem(title: title, imageUrl: imageUrl, href: href)
                        }
                        
                        DispatchQueue.main.async {
                            completion(resultItems)
                        }
                        
                    } else {
                        Logger.shared.log("Failed to parse JSON")
                        DispatchQueue.main.async {
                            completion([])
                        }
                    }
                } catch {
                    Logger.shared.log("JSON parsing error: \(error)")
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            } else {
                Logger.shared.log("Result is not a string")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
        
        let catchBlock: @convention(block) (JSValue) -> Void = { error in
            Logger.shared.log("Promise rejected: \(String(describing: error.toString()))")
            DispatchQueue.main.async {
                completion([])
            }
        }
        
        let thenFunction = JSValue(object: thenBlock, in: context)
        let catchFunction = JSValue(object: catchBlock, in: context)
        
        promise.invokeMethod("then", withArguments: [thenFunction as Any])
        promise.invokeMethod("catch", withArguments: [catchFunction as Any])
    }
    
    func fetchDetailsJS(url: String, completion: @escaping ([MediaItem], [EpisodeLink]) -> Void) {
        guard let url = URL(string: url) else {
            completion([], [])
            return
        }
        
        if let exception = context.exception {
            Logger.shared.log("JavaScript exception: \(exception)")
            completion([], [])
            return
        }
        
        guard let extractDetailsFunction = context.objectForKeyedSubscript("extractDetails") else {
            Logger.shared.log("No JavaScript function extractDetails found")
            completion([], [])
            return
        }
        
        guard let extractEpisodesFunction = context.objectForKeyedSubscript("extractEpisodes") else {
            Logger.shared.log("No JavaScript function extractEpisodes found")
            completion([], [])
            return
        }
        
        var resultItems: [MediaItem] = []
        var episodeLinks: [EpisodeLink] = []
        
        let promiseValueDetails = extractDetailsFunction.call(withArguments: [url.absoluteString])
        guard let promiseDetails = promiseValueDetails else {
            Logger.shared.log("extractDetails did not return a Promise")
            completion([], [])
            return
        }
        
        let thenBlockDetails: @convention(block) (JSValue) -> Void = { result in
            
            if let jsonOfDetails = result.toString(),
               let dataDetails = jsonOfDetails.data(using: .utf8) {
                do {
                    if let array = try JSONSerialization.jsonObject(with: dataDetails, options: []) as? [[String: Any]] {
                        resultItems = array.map { item -> MediaItem in
                            let description = item["description"] as? String ?? ""
                            let aliases = item["aliases"] as? String ?? ""
                            let airdate = item["airdate"] as? String ?? ""
                            return MediaItem(description: description, aliases: aliases, airdate: airdate)
                        }
                    } else {
                        Logger.shared.log("Failed to parse JSON of extractDetails")
                        DispatchQueue.main.async {
                            completion([], [])
                        }
                    }
                } catch {
                    Logger.shared.log("JSON parsing error of extract details: \(error)")
                    DispatchQueue.main.async {
                        completion([], [])
                    }
                }
            } else {
                Logger.shared.log("Result is not a string of extractDetails")
                DispatchQueue.main.async {
                    completion([], [])
                }
            }
        }
        
        let catchBlockDetails: @convention(block) (JSValue) -> Void = { error in
            Logger.shared.log("Promise rejected of extractDetails: \(String(describing: error.toString()))")
            DispatchQueue.main.async {
                completion([], [])
            }
        }
        
        let thenFunctionDetails = JSValue(object: thenBlockDetails, in: context)
        let catchFunctionDetails = JSValue(object: catchBlockDetails, in: context)
        
        promiseDetails.invokeMethod("then", withArguments: [thenFunctionDetails as Any])
        promiseDetails.invokeMethod("catch", withArguments: [catchFunctionDetails as Any])
        
        
        let promiseValueEpisodes = extractEpisodesFunction.call(withArguments: [url.absoluteString])
        guard let promiseEpisodes = promiseValueEpisodes else {
            Logger.shared.log("extractEpisodes did not return a Promise")
            completion([], [])
            return
        }
        
        let thenBlockEpisodes: @convention(block) (JSValue) -> Void = { result in
            
            if let jsonOfEpisodes = result.toString(),
               let dataEpisodes = jsonOfEpisodes.data(using: .utf8) {
                do {
                    if let array = try JSONSerialization.jsonObject(with: dataEpisodes, options: []) as? [[String: Any]] {
                        episodeLinks = array.map { item -> EpisodeLink in
                            let number = item["number"] as? Int ?? 0
                            let href = item["href"] as? String ?? ""
                            return EpisodeLink(number: number, href: href)
                        }
                        
                        DispatchQueue.main.async {
                            completion(resultItems, episodeLinks)
                        }
                        
                    } else {
                        Logger.shared.log("Failed to parse JSON of extractEpisodes")
                        DispatchQueue.main.async {
                            completion([], [])
                        }
                    }
                } catch {
                    Logger.shared.log("JSON parsing error of extractEpisodes: \(error)")
                    DispatchQueue.main.async {
                        completion([], [])
                    }
                }
            } else {
                Logger.shared.log("Result is not a string of extractEpisodes")
                DispatchQueue.main.async {
                    completion([], [])
                }
            }
        }
        
        let catchBlockEpisodes: @convention(block) (JSValue) -> Void = { error in
            Logger.shared.log("Promise rejected of extractEpisodes: \(String(describing: error.toString()))")
            DispatchQueue.main.async {
                completion([], [])
            }
        }
        
        let thenFunctionEpisodes = JSValue(object: thenBlockEpisodes, in: context)
        let catchFunctionEpisodes = JSValue(object: catchBlockEpisodes, in: context)
        
        promiseEpisodes.invokeMethod("then", withArguments: [thenFunctionEpisodes as Any])
        promiseEpisodes.invokeMethod("catch", withArguments: [catchFunctionEpisodes as Any])
    }
    
}
