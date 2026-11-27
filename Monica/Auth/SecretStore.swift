import Foundation
import Security

/// The secrets the app keeps between launches.
enum SecretKey: String, CaseIterable {
    case session
    case pendingSignIn = "pending-sign-in"
    case pendingRevocation = "pending-revocation"
}

/// Where the session and the sign-in in progress are kept. A protocol only so the session manager
/// can be tested without the Keychain.
protocol SecretStore: Sendable {
    func read<Value: Decodable>(_ key: SecretKey, as type: Value.Type) -> Value?
    /// Replaces the value whole, in one step: after a crash, the old or the new value is there,
    /// never a mix.
    func write(_ value: some Encodable, for key: SecretKey) throws
    func delete(_ key: SecretKey)
}

/// The Keychain, readable by this app only, on this device only: the items are never in a backup
/// and never move to another iPhone, so a restored or new phone starts signed out. They can be
/// read once the phone was unlocked after starting, so a renewal works when the app is in the
/// background.
struct KeychainSecretStore: SecretStore {
    struct WriteError: Error {
        let status: OSStatus
    }

    private static let installedKey = "auth_installed"

    let service: String

    init(service: String = "com.monicahq.ios.auth") {
        self.service = service
    }

    private func query(_ key: SecretKey) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue,
        ]
    }

    func read<Value: Decodable>(_ key: SecretKey, as type: Value.Type) -> Value? {
        var search = query(key)
        search[kSecReturnData] = true
        search[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(search as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        guard let value = try? JSONDecoder().decode(type, from: data) else {
            // Written by another version, or damaged: of no use, so it goes.
            delete(key)
            return nil
        }
        return value
    }

    func write(_ value: some Encodable, for key: SecretKey) throws {
        let data = try JSONEncoder().encode(value)
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(query(key) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query(key).merging(attributes) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw WriteError(status: status) }
    }

    func delete(_ key: SecretKey) {
        SecItemDelete(query(key) as CFDictionary)
    }

    /// iOS keeps Keychain items after the app is deleted, but deletes its preferences. With no
    /// marker in the preferences, this is a fresh install: whatever an earlier install left in the
    /// Keychain is deleted, so a reinstalled app starts signed out.
    func wipeIfFreshInstall(defaults: UserDefaults) {
        guard !defaults.bool(forKey: Self.installedKey) else { return }
        for key in SecretKey.allCases {
            delete(key)
        }
        defaults.set(true, forKey: Self.installedKey)
    }
}
