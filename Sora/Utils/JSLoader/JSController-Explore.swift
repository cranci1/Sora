//
//  JSController-Search.swift
//  Sulfur
//
//  Created by Dominic on 24.04.25.
//

import JavaScriptCore

// TODO: implement and test
extension JSController {
    func fetchExploreResults(module: ScrapingModule, completion: @escaping ([ExploreItem]) -> Void) {
        guard let exploreUrl = module.metadata.exploreBaseUrl,
              let url = URL(string: exploreUrl) else {
            completion([])
            return
        }

        URLSession.custom.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }

            if let error {
                Logger.shared.log("Network error: \(error)", type: .error)
                DispatchQueue.main.async { completion([]) }
                return
            }

            guard let data, let html = String(data: data, encoding: .utf8) else {
                Logger.shared.log("Failed to decode HTML", type: .error)
                DispatchQueue.main.async { completion([]) }
                return
            }

            self.context.exceptionHandler = { _, exception in
                Logger.shared.log(exception?.toString() ?? "Unknown JS Exception", type: .error)
            }

            Logger.shared.log(html, type: .html)
            if let parseFunction = self.context.objectForKeyedSubscript("exploreResults"),
               let results = parseFunction.call(withArguments: [html]).toArray() as? [[String: String]] {
                let resultItems = results.map { item in
                    ExploreItem(
                        title: item["title"] ?? "",
                        imageUrl: item["image"] ?? "",
                        href: item["href"] ?? ""
                    )
                }
                DispatchQueue.main.async {
                    completion(resultItems)
                }
            } else {
                Logger.shared.log("Failed to parse results", type: .error)
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }

    func fetchJsExploreResults(module: ScrapingModule, completion: @escaping ([ExploreItem]) -> Void) {
        if let exception = context.exception {
            Logger.shared.log("JavaScript exception: \(exception)", type: .error)
            completion([])
            return
        }

        guard let exploreResultsFunction = context.objectForKeyedSubscript("exploreResults") else {
            Logger.shared.log("No JavaScript function exploreResults found", type: .error)
            completion([])
            return
        }

        let promiseValue = exploreResultsFunction.call(withArguments: [])
        guard let promise = promiseValue else {
            Logger.shared.log("exploreResults did not return a Promise", type: .error)
            completion([])
            return
        }

        let thenBlock: @convention(block) (JSValue) -> Void = { result in
            Logger.shared.log(result.toString(), type: .html)
            if let jsonString = result.toString(),
               let data = jsonString.data(using: .utf8) {
                do {
                    if let array = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        let resultItems = array.compactMap { item -> ExploreItem? in
                            guard let title = item["title"] as? String,
                                  let imageUrl = item["image"] as? String,
                                  let href = item["href"] as? String else {
                                      Logger.shared.log("Missing or invalid data in search result item: \(item)", type: .error)
                                      return nil
                                  }
                            return ExploreItem(title: title, imageUrl: imageUrl, href: href)
                        }

                        DispatchQueue.main.async {
                            completion(resultItems)
                        }
                    } else {
                        Logger.shared.log("Failed to parse JSON", type: .error)
                        DispatchQueue.main.async {
                            completion([])
                        }
                    }
                } catch {
                    Logger.shared.log("JSON parsing error: \(error)", type: .error)
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            } else {
                Logger.shared.log("Result is not a string", type: .error)
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }

        let catchBlock: @convention(block) (JSValue) -> Void = { error in
            Logger.shared.log("Promise rejected: \(String(describing: error.toString()))", type: .error)
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
