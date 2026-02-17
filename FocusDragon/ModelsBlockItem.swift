//
//  BlockItem.swift
//  FocusDragon
//
//  Created by Anay Goenka on 17/02/2026.
//

import Foundation

/// Represents a website or domain to be blocked
struct BlockItem: Identifiable, Codable, Hashable {
    let id: UUID
    var domain: String
    var isEnabled: Bool
    var dateAdded: Date
    
    init(id: UUID = UUID(), domain: String, isEnabled: Bool = true, dateAdded: Date = Date()) {
        self.id = id
        self.domain = domain
        self.isEnabled = isEnabled
        self.dateAdded = dateAdded
    }
}
