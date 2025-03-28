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
        context.setupJavaScriptEnvironment()
    }
    
    func loadScript(_ script: String) {
        context = JSContext()
        setupContext()
        context.evaluateScript(script)
        if let exception = context.exception {
            Logger.shared.log("Error loading script: \(exception)", type: "Error")
        }
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
            
            Logger.shared.log(html,type: "HTMLStrings")
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
            
            Logger.shared.log(html,type: "HTMLStrings")
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
    
    func fetchStreamUrl(episodeUrl: String, softsub: Bool = false, completion: @escaping ((stream: String?, subtitles: String?)) -> Void) {
        guard let url = URL(string: episodeUrl) else {
            completion((nil, nil))
            return
        }
        
        URLSession.custom.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.shared.log("Network error: \(error)", type: "Error")
                DispatchQueue.main.async { completion((nil, nil)) }
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                Logger.shared.log("Failed to decode HTML", type: "Error")
                DispatchQueue.main.async { completion((nil, nil)) }
                return
            }
            
            Logger.shared.log(html, type: "HTMLStrings")
            if let parseFunction = self.context.objectForKeyedSubscript("extractStreamUrl"),
               let resultString = parseFunction.call(withArguments: [html]).toString() {
                if softsub {
                    if let data = resultString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        let streamUrl = json["stream"] as? String
                        let subtitlesUrl = json["subtitles"] as? String
                        Logger.shared.log("Starting stream from: \(streamUrl ?? "nil") with subtitles: \(subtitlesUrl ?? "nil")", type: "Stream")
                        DispatchQueue.main.async {
                            completion((streamUrl, subtitlesUrl))
                        }
                    } else {
                        Logger.shared.log("Failed to parse softsub JSON", type: "Error")
                        DispatchQueue.main.async { completion((nil, nil)) }
                    }
                } else {
                    Logger.shared.log("Starting stream from: \(resultString)", type: "Stream")
                    DispatchQueue.main.async { completion((resultString, nil)) }
                }
            } else {
                Logger.shared.log("Failed to extract stream URL", type: "Error")
                DispatchQueue.main.async { completion((nil, nil)) }
            }
        }.resume()
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
            
            Logger.shared.log(result.toString(),type: "HTMLStrings")
            if let jsonString = result.toString(),
               let data = jsonString.data(using: .utf8) {
                do {
                    if let array = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        let resultItems = array.compactMap { item -> SearchItem? in
                            guard let title = item["title"] as? String,
                                  let imageUrl = item["image"] as? String,
                                  let href = item["href"] as? String else {
                                      Logger.shared.log("Missing or invalid data in search result item: \(item)", type: "Error")
                                      return nil
                                  }
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
    
    func fetchStreamUrlJS(episodeUrl: String, softsub: Bool = false, completion: @escaping ((stream: String?, subtitles: String?)) -> Void) {
        if let exception = context.exception {
            Logger.shared.log("JavaScript exception: \(exception)", type: "Error")
            completion((nil, nil))
            return
        }
        
        guard let extractStreamUrlFunction = context.objectForKeyedSubscript("extractStreamUrl") else {
            Logger.shared.log("No JavaScript function extractStreamUrl found", type: "Error")
            completion((nil, nil))
            return
        }
        
        let promiseValue = extractStreamUrlFunction.call(withArguments: [episodeUrl])
        guard let promise = promiseValue else {
            Logger.shared.log("extractStreamUrl did not return a Promise", type: "Error")
            completion((nil, nil))
            return
        }
        
        let thenBlock: @convention(block) (JSValue) -> Void = { result in
            if softsub {
                if let jsonString = result.toString(),
                   let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    let streamUrl = json["stream"] as? String
                    let subtitlesUrl = json["subtitles"] as? String
                    Logger.shared.log("Starting stream from: \(streamUrl ?? "nil") with subtitles: \(subtitlesUrl ?? "nil")", type: "Stream")
                    DispatchQueue.main.async {
                        completion((streamUrl, subtitlesUrl))
                    }
                } else {
                    Logger.shared.log("Failed to parse softsub JSON in JS", type: "Error")
                    DispatchQueue.main.async {
                        completion((nil, nil))
                    }
                }
            } else {
                let streamUrl = result.toString()
                Logger.shared.log("Starting stream from: \(streamUrl ?? "nil")", type: "Stream")
                DispatchQueue.main.async {
                    completion((streamUrl, nil))
                }
            }
        }
        
        let catchBlock: @convention(block) (JSValue) -> Void = { error in
            Logger.shared.log("Promise rejected: \(String(describing: error.toString()))", type: "Error")
            DispatchQueue.main.async {
                completion((nil, nil))
            }
        }
        
        let thenFunction = JSValue(object: thenBlock, in: context)
        let catchFunction = JSValue(object: catchBlock, in: context)
        
        promise.invokeMethod("then", withArguments: [thenFunction as Any])
        promise.invokeMethod("catch", withArguments: [catchFunction as Any])
    }
    
    func fetchStreamUrlJSSecond(episodeUrl: String, softsub: Bool = false, completion: @escaping ((stream: String?, subtitles: String?)) -> Void) {
        let url = URL(string: episodeUrl)!
        let task = URLSession.custom.dataTask(with: url) { data, response, error in
            if let error = error {
                Logger.shared.log("URLSession error: \(error.localizedDescription)", type: "Error")
                DispatchQueue.main.async { completion((nil, nil)) }
                return
            }
            
            guard let data = data, let htmlString = String(data: data, encoding: .utf8) else {
                Logger.shared.log("Failed to fetch HTML data", type: "Error")
                DispatchQueue.main.async { completion((nil, nil)) }
                return
            }
            
            DispatchQueue.main.async {
                if let exception = self.context.exception {
                    Logger.shared.log("JavaScript exception: \(exception)", type: "Error")
                    completion((nil, nil))
                    return
                }
                
                guard let extractStreamUrlFunction = self.context.objectForKeyedSubscript("extractStreamUrl") else {
                    Logger.shared.log("No JavaScript function extractStreamUrl found", type: "Error")
                    completion((nil, nil))
                    return
                }
                
                let promiseValue = extractStreamUrlFunction.call(withArguments: [htmlString])
                guard let promise = promiseValue else {
                    Logger.shared.log("extractStreamUrl did not return a Promise", type: "Error")
                    completion((nil, nil))
                    return
                }
                
                let thenBlock: @convention(block) (JSValue) -> Void = { result in
                    if softsub {
                        if let jsonString = result.toString(),
                           let data = jsonString.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            let streamUrl = json["stream"] as? String
                            let subtitlesUrl = json["subtitles"] as? String
                            Logger.shared.log("Starting stream from: \(streamUrl ?? "nil") with subtitles: \(subtitlesUrl ?? "nil")", type: "Stream")
                            DispatchQueue.main.async {
                                completion((streamUrl, subtitlesUrl))
                            }
                        } else {
                            Logger.shared.log("Failed to parse softsub JSON in JSSecond", type: "Error")
                            DispatchQueue.main.async {
                                completion((nil, nil))
                            }
                        }
                    } else {
                        let streamUrl = result.toString()
                        Logger.shared.log("Starting stream from: \(streamUrl ?? "nil")", type: "Stream")
                        DispatchQueue.main.async {
                            completion((streamUrl, nil))
                        }
                    }
                }
                
                let catchBlock: @convention(block) (JSValue) -> Void = { error in
                    Logger.shared.log("Promise rejected: \(String(describing: error.toString()))", type: "Error")
                    DispatchQueue.main.async {
                        completion((nil, nil))
                    }
                }
                
                let thenFunction = JSValue(object: thenBlock, in: self.context)
                let catchFunction = JSValue(object: catchBlock, in: self.context)
                
                promise.invokeMethod("then", withArguments: [thenFunction as Any])
                promise.invokeMethod("catch", withArguments: [catchFunction as Any])
            }
        }
        task.resume()
    }
}
