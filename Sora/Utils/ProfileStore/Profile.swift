//
//  Profile.swift
//  Sulfur
//
//  Created by Dominic on 21.04.25.
//

import Foundation

struct Profile: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
}
