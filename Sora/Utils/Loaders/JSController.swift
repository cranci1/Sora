//
//  JSController.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import JavaScriptCore

class JSController: ObservableObject {
    private var context: JSContext
    
    init() {
        self.context = JSContext()
        setupContext()
    }
    
    private func setupContext() {
        let logFunction: @convention(block) (String) -> Void = { message in
            Logger.shared.log("JavaScript log: \(message)", type: "Debug")
        }
        context.setObject(logFunction, forKeyedSubscript: "log" as NSString)
        
        let fetchNativeFunction: @convention(block) (String, JSValue, JSValue) -> Void = { urlString, resolve, reject in
            guard let url = URL(string: urlString) else {
                Logger.shared.log("Invalid URL",type: "Error")
                reject.call(withArguments: ["Invalid URL"])
                return
            }
            let task = URLSession.custom.dataTask(with: url) { data, _, error in
                if let error = error {
                    Logger.shared.log("Network error in fetchNativeFunction: \(error.localizedDescription)",type: "Error")
                    reject.call(withArguments: [error.localizedDescription])
                    return
                }
                guard let data = data else {
                    Logger.shared.log("No data in response",type: "Error")
                    reject.call(withArguments: ["No data"])
                    return
                }
                if let text = String(data: data, encoding: .utf8) {
                    resolve.call(withArguments: [text])
                } else {
                    Logger.shared.log("Unable to decode data to text",type: "Error")
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
                Logger.shared.log("Network error: \(error)",type: "Error")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                Logger.shared.log("Failed to decode HTML",type: "Error")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            Logger.shared.log(html,type: "Debug")
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
                Logger.shared.log("Failed to parse results",type: "Error")
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
                Logger.shared.log("Network error: \(error)",type: "Error")
                DispatchQueue.main.async { completion([], []) }
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                Logger.shared.log("Failed to decode HTML",type: "Error")
                DispatchQueue.main.async { completion([], []) }
                return
            }
            
            var resultItems: [MediaItem] = []
            var episodeLinks: [EpisodeLink] = []
            
            Logger.shared.log(html,type: "Debug")
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
                Logger.shared.log("Failed to parse results",type: "Error")
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
    if let exception = context.exception {
        Logger.shared.log("JavaScript exception: \(exception)", type: "Error")
        completion(nil)
        return
    }
    
    guard let extractStreamUrlFunction = context.objectForKeyedSubscript("extractStreamUrl") else {
        Logger.shared.log("No JavaScript function extractStreamUrl found", type: "Error")
        completion(nil)
        return
    }
    
    let promiseValue = extractStreamUrlFunction.call(withArguments: [episodeUrl])
    guard let promise = promiseValue else {
        Logger.shared.log("extractStreamUrl did not return a Promise", type: "Error")
        completion(nil)
        return
    }
    
    let thenBlock: @convention(block) (JSValue) -> Void = { result in
        let streamUrl = result.toString()
        Logger.shared.log("Starting stream from: \(streamUrl ?? "nil")", type: "Stream")
        DispatchQueue.main.async {
            completion(streamUrl)
        }
    }
    
    let catchBlock: @convention(block) (JSValue) -> Void = { error in
        Logger.shared.log("Promise rejected: \(String(describing: error.toString()))", type: "Error")
        DispatchQueue.main.async {
            completion(nil)
        }
    }
    
    let thenFunction = JSValue(object: thenBlock, in: context)
    let catchFunction = JSValue(object: catchBlock, in: context)
    
    promise.invokeMethod("then", withArguments: [thenFunction as Any])
    promise.invokeMethod("catch", withArguments: [catchFunction as Any])
    }
    
    func fetchJsSearchResults(keyword: String, module: ScrapingModule, completion: @escaping ([SearchItem]) -> Void) {
        if let exception = context.exception {
            Logger.shared.log("JavaScript exception: \(exception)",type: "Error")
            completion([])
            return
        }
        
        guard let searchResultsFunction = context.objectForKeyedSubscript("searchResults") else {
            Logger.shared.log("No JavaScript function searchResults found",type: "Error")
            completion([])
            return
        }
        
        let promiseValue = searchResultsFunction.call(withArguments: [keyword])
        guard let promise = promiseValue else {
            Logger.shared.log("searchResults did not return a Promise",type: "Error")
            completion([])
            return
        }
        
        let thenBlock: @convention(block) (JSValue) -> Void = { result in
            
            Logger.shared.log(result.toString(),type: "Debug")
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
                        Logger.shared.log("Failed to parse JSON",type: "Error")
                        DispatchQueue.main.async {
                            completion([])
                        }
                    }
                } catch {
                    Logger.shared.log("JSON parsing error: \(error)",type: "Error")
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            } else {
                Logger.shared.log("Result is not a string",type: "Error")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
        
        let catchBlock: @convention(block) (JSValue) -> Void = { error in
            Logger.shared.log("Promise rejected: \(String(describing: error.toString()))",type: "Error")
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
            Logger.shared.log("JavaScript exception: \(exception)",type: "Error")
            completion([], [])
            return
        }
        
        guard let extractDetailsFunction = context.objectForKeyedSubscript("extractDetails") else {
            Logger.shared.log("No JavaScript function extractDetails found",type: "Error")
            completion([], [])
            return
        }
        
        guard let extractEpisodesFunction = context.objectForKeyedSubscript("extractEpisodes") else {
            Logger.shared.log("No JavaScript function extractEpisodes found",type: "Error")
            completion([], [])
            return
        }
        
        var resultItems: [MediaItem] = []
        var episodeLinks: [EpisodeLink] = []
        
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        let promiseValueDetails = extractDetailsFunction.call(withArguments: [url.absoluteString])
        guard let promiseDetails = promiseValueDetails else {
            Logger.shared.log("extractDetails did not return a Promise",type: "Error")
            completion([], [])
            return
        }
        
        let thenBlockDetails: @convention(block) (JSValue) -> Void = { result in
            Logger.shared.log(result.toString(),type: "Debug")
            if let jsonOfDetails = result.toString(),
               let dataDetails = jsonOfDetails.data(using: .utf8) {
                do {
                    if let array = try JSONSerialization.jsonObject(with: dataDetails, options: []) as? [[String: Any]] {
                        resultItems = array.map { item -> MediaItem in
                            MediaItem(
                                description: item["description"] as? String ?? "",
                                aliases: item["aliases"] as? String ?? "",
                                airdate: item["airdate"] as? String ?? ""
                            )
                        }
                    } else {
                        Logger.shared.log("Failed to parse JSON of extractDetails",type: "Error")
                    }
                } catch {
                    Logger.shared.log("JSON parsing error of extract details: \(error)",type: "Error")
                }
            } else {
                Logger.shared.log("Result is not a string of extractDetails",type: "Error")
            }
            dispatchGroup.leave()
        }
        
        let catchBlockDetails: @convention(block) (JSValue) -> Void = { error in
            Logger.shared.log("Promise rejected of extractDetails: \(String(describing: error.toString()))",type: "Error")
            dispatchGroup.leave()
        }
        
        let thenFunctionDetails = JSValue(object: thenBlockDetails, in: context)
        let catchFunctionDetails = JSValue(object: catchBlockDetails, in: context)
        
        promiseDetails.invokeMethod("then", withArguments: [thenFunctionDetails as Any])
        promiseDetails.invokeMethod("catch", withArguments: [catchFunctionDetails as Any])
        
        dispatchGroup.enter()
        let promiseValueEpisodes = extractEpisodesFunction.call(withArguments: [url.absoluteString])
        guard let promiseEpisodes = promiseValueEpisodes else {
            Logger.shared.log("extractEpisodes did not return a Promise",type: "Error")
            completion([], [])
            return
        }
        
        let thenBlockEpisodes: @convention(block) (JSValue) -> Void = { result in
            Logger.shared.log(result.toString(),type: "Debug")
            if let jsonOfEpisodes = result.toString(),
               let dataEpisodes = jsonOfEpisodes.data(using: .utf8) {
                do {
                    if let array = try JSONSerialization.jsonObject(with: dataEpisodes, options: []) as? [[String: Any]] {
                        episodeLinks = array.map { item -> EpisodeLink in
                            EpisodeLink(
                                number: item["number"] as? Int ?? 0,
                                href: item["href"] as? String ?? ""
                            )
                        }
                    } else {
                        Logger.shared.log("Failed to parse JSON of extractEpisodes",type: "Error")
                    }
                } catch {
                    Logger.shared.log("JSON parsing error of extractEpisodes: \(error)",type: "Error")
                }
            } else {
                Logger.shared.log("Result is not a string of extractEpisodes",type: "Error")
            }
            dispatchGroup.leave()
        }
        
        let catchBlockEpisodes: @convention(block) (JSValue) -> Void = { error in
            Logger.shared.log("Promise rejected of extractEpisodes: \(String(describing: error.toString()))",type: "Error")
            dispatchGroup.leave()
        }
        
        let thenFunctionEpisodes = JSValue(object: thenBlockEpisodes, in: context)
        let catchFunctionEpisodes = JSValue(object: catchBlockEpisodes, in: context)
        
        promiseEpisodes.invokeMethod("then", withArguments: [thenFunctionEpisodes as Any])
        promiseEpisodes.invokeMethod("catch", withArguments: [catchFunctionEpisodes as Any])
        
        dispatchGroup.notify(queue: .main) {
            completion(resultItems, episodeLinks)
        }
    }
}
