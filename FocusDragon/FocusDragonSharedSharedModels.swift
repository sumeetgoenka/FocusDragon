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
    public static let safariExtensionIdentifier = "com.anaygoenka.FocusDragon.FocusDragonSafariExtension"
    public static let appGroupIdentifier = "group.com.focusdragon.shared"
    public static let safariHeartbeatKey = "safariExtensionHeartbeat"
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

// MARK: - Exceptions

public struct URLException: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var domain: String
    public var allowedPaths: [String]

    public init(id: UUID = UUID(), domain: String, allowedPaths: [String]) {
        self.id = id
        self.domain = domain
        self.allowedPaths = allowedPaths
    }
}

public struct ExceptionSchedule: Codable, Equatable, Hashable, Sendable {
    /// 1-7 for Sunday-Saturday (Calendar.current weekday values)
    public var days: Set<Int>
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int

    public init(days: Set<Int>, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.days = days
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    public func isActive(on date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        if !days.isEmpty, !days.contains(weekday) {
            return false
        }

        let start = DateComponents(hour: startHour, minute: startMinute)
        let end = DateComponents(hour: endHour, minute: endMinute)

        guard let startDate = calendar.date(bySettingHour: start.hour ?? 0,
                                            minute: start.minute ?? 0,
                                            second: 0, of: date),
              let endDate = calendar.date(bySettingHour: end.hour ?? 0,
                                          minute: end.minute ?? 0,
                                          second: 0, of: date) else {
            return false
        }

        if endDate <= startDate {
            // Schedule spans midnight
            return date >= startDate || date < endDate
        }

        return date >= startDate && date < endDate
    }
}

public struct AppException: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var bundleIdentifier: String
    public var appName: String
    public var alwaysAllow: Bool
    public var schedules: [ExceptionSchedule]

    public init(id: UUID = UUID(),
                bundleIdentifier: String,
                appName: String,
                alwaysAllow: Bool = true,
                schedules: [ExceptionSchedule] = []) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.alwaysAllow = alwaysAllow
        self.schedules = schedules
    }

    public func isActive(on date: Date, calendar: Calendar = .current) -> Bool {
        if alwaysAllow {
            return true
        }
        if schedules.isEmpty {
            return false
        }
        return schedules.contains { $0.isActive(on: date, calendar: calendar) }
    }
}

// MARK: - Frozen Mode

public enum FrozenMode: String, Codable, Sendable {
    case lockScreen
    case logout
    case shutdown
    case limitedAccess

    public var displayName: String {
        switch self {
        case .lockScreen: return "Lock Screen"
        case .logout: return "Logout"
        case .shutdown: return "Shutdown"
        case .limitedAccess: return "Limited Access"
        }
    }
}

public struct FrozenState: Codable, Equatable, Sendable {
    public var isActive: Bool
    public var mode: FrozenMode
    public var startedAt: Date
    public var expiresAt: Date?
    public var allowedAppBundleIDs: [String]

    public init(isActive: Bool,
                mode: FrozenMode,
                startedAt: Date,
                expiresAt: Date? = nil,
                allowedAppBundleIDs: [String] = []) {
        self.isActive = isActive
        self.mode = mode
        self.startedAt = startedAt
        self.expiresAt = expiresAt
        self.allowedAppBundleIDs = allowedAppBundleIDs
    }

    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }
}

// MARK: - Internet Blocking

public struct InternetBlockConfig: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var whitelistDomains: [String]
    public var whitelistApps: [String]

    public init(isEnabled: Bool = false,
                whitelistDomains: [String] = [],
                whitelistApps: [String] = []) {
        self.isEnabled = isEnabled
        self.whitelistDomains = whitelistDomains
        self.whitelistApps = whitelistApps
    }
}

// MARK: - Daemon Configuration

/// Configuration structure shared between app and daemon
public struct DaemonConfig: Codable, Equatable, Sendable {
    public var version: String
    public var isBlocking: Bool
    public var lastModified: Date
    public var blockedDomains: [String]
    public var blockedApps: [BlockedApp]
    public var urlExceptions: [URLException]
    public var appExceptions: [AppException]
    public var internetBlockConfig: InternetBlockConfig?
    public var frozenState: FrozenState?
    public var lockState: SharedLockState?
    public var timerLockExpiry: Date?
    public var requireBrowserExtension: Bool

    public var isLocked: Bool {
        guard let lockState = lockState else { return false }

        // Check timer lock
        if lockState.lockType == "timer",
           let expiry = timerLockExpiry {
            return Date() < expiry
        }

        return lockState.isLocked
    }

    public struct BlockedApp: Codable, Equatable, Sendable {
        public let bundleIdentifier: String
        public let appName: String

        public init(bundleIdentifier: String, appName: String) {
            self.bundleIdentifier = bundleIdentifier
            self.appName = appName
        }
    }

    public init(version: String = "1.1", isBlocking: Bool = false,
                lastModified: Date = Date(), blockedDomains: [String] = [],
                blockedApps: [BlockedApp] = [], urlExceptions: [URLException] = [],
                appExceptions: [AppException] = [],
                internetBlockConfig: InternetBlockConfig? = nil,
                frozenState: FrozenState? = nil,
                lockState: SharedLockState? = nil,
                timerLockExpiry: Date? = nil, requireBrowserExtension: Bool = true) {
        self.version = version
        self.isBlocking = isBlocking
        self.lastModified = lastModified
        self.blockedDomains = blockedDomains
        self.blockedApps = blockedApps
        self.urlExceptions = urlExceptions
        self.appExceptions = appExceptions
        self.internetBlockConfig = internetBlockConfig
        self.frozenState = frozenState
        self.lockState = lockState
        self.timerLockExpiry = timerLockExpiry
        self.requireBrowserExtension = requireBrowserExtension
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case isBlocking
        case lastModified
        case blockedDomains
        case blockedApps
        case urlExceptions
        case appExceptions
        case internetBlockConfig
        case frozenState
        case lockState
        case timerLockExpiry
        case requireBrowserExtension
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.1"
        isBlocking = try container.decodeIfPresent(Bool.self, forKey: .isBlocking) ?? false
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
        blockedDomains = try container.decodeIfPresent([String].self, forKey: .blockedDomains) ?? []
        blockedApps = try container.decodeIfPresent([BlockedApp].self, forKey: .blockedApps) ?? []
        urlExceptions = try container.decodeIfPresent([URLException].self, forKey: .urlExceptions) ?? []
        appExceptions = try container.decodeIfPresent([AppException].self, forKey: .appExceptions) ?? []
        internetBlockConfig = try container.decodeIfPresent(InternetBlockConfig.self, forKey: .internetBlockConfig)
        frozenState = try container.decodeIfPresent(FrozenState.self, forKey: .frozenState)
        lockState = try container.decodeIfPresent(SharedLockState.self, forKey: .lockState)
        timerLockExpiry = try container.decodeIfPresent(Date.self, forKey: .timerLockExpiry)
        requireBrowserExtension = try container.decodeIfPresent(Bool.self, forKey: .requireBrowserExtension) ?? true
    }
}

/// Lock state for tamper-resistant blocking
public struct SharedLockState: Codable, Equatable, Sendable {
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
