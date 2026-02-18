//
//  BlockItem.swift
//  FocusDragon
//
//  Created by Anay Goenka on 17/02/2026.
//

import Foundation

enum BlockType: String, Codable {
    case website
    case application
}

/// Represents a website or application to be blocked
struct BlockItem: Identifiable, Codable, Hashable {
    let id: UUID
    var type: BlockType
    var domain: String? // For websites
    var appName: String? // For applications
    var bundleIdentifier: String? // For applications
    var appIconPath: String? // Path to app icon
    var isEnabled: Bool
    var dateAdded: Date

    // Website initializer
    init(id: UUID = UUID(), domain: String, isEnabled: Bool = true, dateAdded: Date = Date()) {
        self.id = id
        self.type = .website
        self.domain = domain
        self.isEnabled = isEnabled
        self.dateAdded = dateAdded
    }

    // Application initializer
    init(id: UUID = UUID(), appName: String, bundleIdentifier: String, iconPath: String? = nil, isEnabled: Bool = true, dateAdded: Date = Date()) {
        self.id = id
        self.type = .application
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.appIconPath = iconPath
        self.isEnabled = isEnabled
        self.dateAdded = dateAdded
    }

    var displayName: String {
        switch type {
        case .website:
            return domain ?? "Unknown"
        case .application:
            return appName ?? "Unknown App"
        }
    }
}
