//
//  JSControllerDetails.swift
//  Sulfur
//
//  Created by Francesco on 30/03/25.
//

import Foundation
import JavaScriptCore

extension JSController {
    
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
                        episodeLinks.append(EpisodeLink(number: number, title: "", href: link, duration: nil))
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(resultItems, episodeLinks)
            }
        }.resume()
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
                                title: "",
                                href: item["href"] as? String ?? "",
                                duration: nil
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

struct EpisodeLink: Identifiable {
    let id = UUID()
    let number: Int
    let title: String
    let href: String
    let duration: Int?
}
