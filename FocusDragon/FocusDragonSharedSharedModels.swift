//
//  SharedModels.swift
//  FocusDragonShared
//
//  Created by Anay Goenka on 17/02/2026.
//

import Foundation

/// Models and utilities shared between the main app and daemon/helper processes

// MARK: - Shared Constants

public enum SharedConstants {
    public static let appBundleIdentifier = "com.anaygoenka.FocusDragon"
    public static let helperBundleIdentifier = "com.anaygoenka.FocusDragon.Helper"
    public static let hostsFilePath = "/etc/hosts"
    public static let blockMarkerStart = "# FocusDragon Start"
    public static let blockMarkerEnd = "# FocusDragon End"
}

// MARK: - Shared Block Item

/// Shared representation of a blocked item (used by both app and daemon)
public struct SharedBlockItem: Codable, Sendable {
    public let id: String
    public let url: String
    public let isEnabled: Bool
    
    public init(id: String, url: String, isEnabled: Bool) {
        self.id = id
        self.url = url
        self.isEnabled = isEnabled
    }
}

// MARK: - IPC Message Types

/// Messages used for inter-process communication between app and helper
public enum IPCMessage: Codable, Sendable {
    case updateBlockList([SharedBlockItem])
    case enableBlocking
    case disableBlocking
    case getStatus
    case statusResponse(isActive: Bool, blockedCount: Int)
}
