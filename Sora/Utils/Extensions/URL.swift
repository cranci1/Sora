//
//  URL.swift
//  Sulfur
//
//  Created by Francesco on 23/03/25.
//

import Foundation

extension URL {
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else { return nil }
        var params = [String: String]()
        for queryItem in queryItems {
            params[queryItem.name] = queryItem.value
        }
        return params
    }
}
