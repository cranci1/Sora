//
//  JSController-Search.swift
//  Sulfur
//
//  Created by Francesco on 30/03/25.
//

import JavaScriptCore

extension JSController {
    
    func fetchSearchResults(keyword: String, module: ScrapingModule, completion: @escaping ([SearchItem]) -> Void) {
        let searchUrl = module.metadata.searchBaseUrl.replacingOccurrences(of: "%s", with: keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        
        guard let url = URL(string: searchUrl) else {
            completion([])
            return
        }
        
        URLSession.custom.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.shared.log("Network error while searching: \(error)", type: "Error")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                Logger.shared.log("Could not decode HTML response", type: "Error")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            Logger.shared.log(html, type: "HTMLStrings")
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
                Logger.shared.log("Could not parse search results", type: "Error")
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
    
    func fetchJsSearchResults(keyword: String, module: ScrapingModule, completion: @escaping ([SearchItem]) -> Void) {
        if let exception = context.exception {
            Logger.shared.log("JavaScript exception: \(exception)", type: "Error")
            completion([])
            return
        }
        
        guard let searchResultsFunction = context.objectForKeyedSubscript("searchResults") else {
            Logger.shared.log("Search function not found in module", type: "Error")
            completion([])
            return
        }
        
        let promiseValue = searchResultsFunction.call(withArguments: [keyword])
        guard let promise = promiseValue else {
            Logger.shared.log("Search function returned invalid response", type: "Error")
            completion([])
            return
        }
        
        let thenBlock: @convention(block) (JSValue) -> Void = { result in
            
            Logger.shared.log(result.toString(), type: "HTMLStrings")
            if let jsonString = result.toString(),
               let data = jsonString.data(using: .utf8) {
                do {
                    if let array = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        let resultItems = array.compactMap { item -> SearchItem? in
                            guard let title = item["title"] as? String,
                                  let imageUrl = item["image"] as? String,
                                  let href = item["href"] as? String else {
                                      Logger.shared.log("Invalid search result data format", type: "Error")
                                      return nil
                                  }
                            return SearchItem(title: title, imageUrl: imageUrl, href: href)
                        }
                        
                        DispatchQueue.main.async {
                            completion(resultItems)
                        }
                        
                    } else {
                        Logger.shared.log("Could not parse JSON response", type: "Error")
                        DispatchQueue.main.async {
                            completion([])
                        }
                    }
                } catch {
                    Logger.shared.log("JSON parsing error: \(error)", type: "Error")
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            } else {
                Logger.shared.log("Invalid search result format", type: "Error")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
        
        let catchBlock: @convention(block) (JSValue) -> Void = { error in
            Logger.shared.log("Search operation failed: \(String(describing: error.toString()))", type: "Error")
            DispatchQueue.main.async {
                completion([])
            }
        }
        
        let thenFunction = JSValue(object: thenBlock, in: context)
        let catchFunction = JSValue(object: catchBlock, in: context)
        
        promise.invokeMethod("then", withArguments: [thenFunction as Any])
        promise.invokeMethod("catch", withArguments: [catchFunction as Any])
    }
}
