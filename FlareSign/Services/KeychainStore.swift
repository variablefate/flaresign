import Foundation
import Security

/// Stores private keys in the iOS Keychain.
///
/// Keys are stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` —
/// encrypted at rest, accessible only when the device is unlocked,
/// not included in backups or transferred to new devices.
enum KeychainStore {
    private static let service = "com.flaresign.keys"

    /// Save a private key hex string for a public key.
    static func save(privateKeyHex: String, for publicKeyHex: String) throws {
        let data = Data(privateKeyHex.utf8)

        // Delete existing if present (upsert)
        delete(for: publicKeyHex)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: publicKeyHex,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.osError(status)
        }
    }

    /// Load a private key hex string for a public key.
    static func load(for publicKeyHex: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: publicKeyHex,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Delete a private key for a public key.
    @discardableResult
    static func delete(for publicKeyHex: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: publicKeyHex,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if a private key exists for a public key.
    static func exists(for publicKeyHex: String) -> Bool {
        load(for: publicKeyHex) != nil
    }
}

enum KeychainError: Error, LocalizedError {
    case osError(OSStatus)

    var errorDescription: String? {
        "Keychain error: \(SecCopyErrorMessageString(osStatus, nil) ?? "unknown" as CFString)"
    }

    private var osStatus: OSStatus {
        switch self {
        case .osError(let status): status
        }
    }
}
