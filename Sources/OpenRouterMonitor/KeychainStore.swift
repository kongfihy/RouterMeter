import Foundation
import Security

enum KeychainStoreError: Error {
    case unhandled(OSStatus)
}

struct KeychainStore {
    private let service = "dev.openrouter.monitor"
    private let account = "openrouter-api-key"

    func saveAPIKey(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        var query = baseQuery()
        query[kSecValueData as String] = data

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainStoreError.unhandled(status) }
    }

    func loadAPIKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else { throw KeychainStoreError.unhandled(status) }
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unhandled(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
