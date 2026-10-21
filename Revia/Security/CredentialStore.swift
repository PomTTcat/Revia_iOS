import Foundation
import Security

protocol CredentialStorage {
    func read() throws -> String?
    func save(_ key: String) throws
    func delete() throws
}

struct CredentialStore: CredentialStorage {
    private let service = "Revia.ElevenLabs"
    private let account = "validated-api-key"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    func read() throws -> String? {
        var query = self.query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            throw ReviaError.message(L("keychain_read_failed"))
        }
        return key
    }
    func save(_ key: String) throws {
        let attributes: [String: Any] = [kSecValueData as String: Data(key.utf8), kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            guard SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess else {
                throw ReviaError.message(L("key_save_failed"))
            }
        } else if status != errSecSuccess { throw ReviaError.message(L("key_update_failed")) }
    }
    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw ReviaError.message(L("key_remove_failed")) }
    }
}
