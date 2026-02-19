import Foundation

/// Protection levels that gate which anti-tamper mechanisms are active.
///
/// - Level 0: No protection — basic blocking, can stop anytime
/// - Level 1: Standard — lock mechanisms + daemon enforcement + uninstall prevention
/// - Level 2: Strict — + System Settings / Terminal / Activity Monitor blocking
/// - Level 3: Paranoid — + all text editors / network tools blocked, password required, tamper logging
enum ProtectionLevel: Int, Codable, CaseIterable, Comparable {
    case none = 0
    case standard = 1
    case strict = 2
    case paranoid = 3

    var displayName: String {
        switch self {
        case .none: return "No Protection"
        case .standard: return "Standard"
        case .strict: return "Strict"
        case .paranoid: return "Paranoid"
        }
    }

    var description: String {
        switch self {
        case .none:
            return "Basic blocking only. Can stop anytime."
        case .standard:
            return "Lock mechanisms active. Daemon protects hosts file. Uninstall blocked during locks."
        case .strict:
            return "System Settings, Terminal, and Activity Monitor blocked during locks."
        case .paranoid:
            return "All text editors and network tools blocked. Password required for settings. Full tamper logging."
        }
    }

    var icon: String {
        switch self {
        case .none: return "shield"
        case .standard: return "shield.lefthalf.filled"
        case .strict: return "shield.fill"
        case .paranoid: return "shield.checkered"
        }
    }

    // Feature gating
    var hasLockMechanisms: Bool { self >= .standard }
    var hasDaemonProtection: Bool { self >= .standard }
    var hasUninstallPrevention: Bool { self >= .standard }
    var hasSystemSettingsBlocking: Bool { self >= .strict }
    var hasTerminalBlocking: Bool { self >= .strict }
    var hasActivityMonitorBlocking: Bool { self >= .strict }
    var hasFileSystemMonitoring: Bool { self >= .strict }
    var hasProcessProtection: Bool { self >= .standard }
    var hasPasswordProtection: Bool { self >= .paranoid }
    var hasTamperLogging: Bool { self >= .paranoid }

    static func < (lhs: ProtectionLevel, rhs: ProtectionLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: - Persistence

    private static let key = "focusDragon.protectionLevel"

    static var current: ProtectionLevel {
        get {
            let raw = UserDefaults.standard.integer(forKey: key)
            return ProtectionLevel(rawValue: raw) ?? .none
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}
