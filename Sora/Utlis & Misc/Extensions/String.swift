//
//  String.swift
//  Sora
//
//  Created by Francesco on 14/02/25.
//

import Foundation

extension String {
    var strippedHTML: String {
        guard let data = self.data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil)
        return attributedString?.string ?? self
    }
    
    var trimmed: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
