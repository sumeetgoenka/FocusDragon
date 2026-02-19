import Foundation
import Security
import CryptoKit
import Combine

/// Manages settings protection: password-based access control, uninstall prevention during locks,
/// and secure storage of sensitive lock state via the macOS Keychain.
class SettingsProtection: ObservableObject {
    static let shared = SettingsProtection()

    @Published var isPasswordProtected: Bool = false
    @Published var isAuthenticated: Bool = false

    private let userDefaults = UserDefaults.standard
    private let passwordEnabledKey = "focusDragon.passwordProtected"
    private let keychainService = "com.focusdragon.settings"
    private let keychainAccount = "settingsPassword"

    private init() {
        isPasswordProtected = userDefaults.bool(forKey: passwordEnabledKey)
    }

    // MARK: - Password Management

    /// Set a new settings password. Stores it in the macOS Keychain.
    func setPassword(_ password: String) -> Bool {
        guard !password.isEmpty else { return false }

        let hashed = hashPassword(password)

        if saveToKeychain(hashed) {
            isPasswordProtected = true
            isAuthenticated = true
            userDefaults.set(true, forKey: passwordEnabledKey)
            return true
        }
        return false
    }

    /// Verify the entered password against the stored hash.
    func authenticate(_ password: String) -> Bool {
        guard let storedHash = readFromKeychain() else { return false }
        let inputHash = hashPassword(password)

        if inputHash == storedHash {
            isAuthenticated = true
            return true
        }
        return false
    }

    /// Remove password protection.
    func removePassword() {
        deleteFromKeychain()
        isPasswordProtected = false
        isAuthenticated = false
        userDefaults.set(false, forKey: passwordEnabledKey)
    }

    /// Lock the settings (require re-authentication).
    func lockSettings() {
        isAuthenticated = false
    }

    /// Whether the user needs to authenticate before accessing settings.
    var requiresAuthentication: Bool {
        return isPasswordProtected && !isAuthenticated
    }

    // MARK: - Uninstall Prevention

    /// Returns true if the app should block uninstall attempts (any lock is active).
    func shouldPreventUninstall() -> Bool {
        let lockManager = LockManager.shared
        return lockManager.currentLock.isLocked
    }

    /// Returns true if the daemon plist should be protected from removal.
    func shouldProtectDaemon() -> Bool {
        return shouldPreventUninstall()
    }

    // MARK: - Secure Lock State Storage

    /// Save critical lock state to Keychain for tamper resistance.
    func secureLockState(_ state: LockState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        let key = "lockState"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        // Add new
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// Read lock state from Keychain.
    func readSecureLockState() -> LockState? {
        let key = "lockState"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let state = try? JSONDecoder().decode(LockState.self, from: data) else {
            return nil
        }

        return state
    }

    // MARK: - Keychain Helpers

    private func hashPassword(_ password: String) -> String {
        guard let data = password.data(using: .utf8) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func saveToKeychain(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        // Add new
        var addQuery = query
        addQuery[kSecValueData as String] = data
        let status = SecItemAdd(addQuery as CFDictionary, nil)

        return status == errSecSuccess
    }

    private func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]

        SecItemDelete(query as CFDictionary)
    }
}
