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

// MARK: - Daemon Configuration

/// Configuration structure shared between app and daemon
public struct DaemonConfig: Codable, Equatable, Sendable {
    public var version: String
    public var isBlocking: Bool
    public var lastModified: Date
    public var blockedDomains: [String]
    public var blockedApps: [BlockedApp]
    public var lockState: LockState?

    public struct BlockedApp: Codable, Equatable, Sendable {
        public let bundleIdentifier: String
        public let appName: String

        public init(bundleIdentifier: String, appName: String) {
            self.bundleIdentifier = bundleIdentifier
            self.appName = appName
        }
    }

    public init(version: String = "1.0", isBlocking: Bool = false,
                lastModified: Date = Date(), blockedDomains: [String] = [],
                blockedApps: [BlockedApp] = [], lockState: LockState? = nil) {
        self.version = version
        self.isBlocking = isBlocking
        self.lastModified = lastModified
        self.blockedDomains = blockedDomains
        self.blockedApps = blockedApps
        self.lockState = lockState
    }
}

/// Lock state for tamper-resistant blocking
public struct LockState: Codable, Equatable, Sendable {
    public var isLocked: Bool
    public var lockType: String
    public var expiresAt: Date?
    public var randomText: String?
    public var requireRestart: Bool

    public init(isLocked: Bool, lockType: String, expiresAt: Date? = nil,
                randomText: String? = nil, requireRestart: Bool = false) {
        self.isLocked = isLocked
        self.lockType = lockType
        self.expiresAt = expiresAt
        self.randomText = randomText
        self.requireRestart = requireRestart
    }
}
