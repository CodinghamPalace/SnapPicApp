//  KeychainHelper.swift
//  SnapPic
//  Lightweight keychain wrapper for storing auth tokens.

import Foundation
import Security

enum KeychainError: Error { case unexpectedStatus(OSStatus) }

struct KeychainHelper {
    static func save(service: String, account: String, value: Data) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        // Delete existing
        SecItemDelete(query as CFDictionary)
        var newItem = query
        newItem[kSecValueData as String] = value
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(newItem as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    static func read(service: String, account: String) throws -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess { return result as? Data }
        if status == errSecItemNotFound { return nil }
        throw KeychainError.unexpectedStatus(status)
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
    }
}

extension KeychainHelper {
    static let service = "com.snapPic.auth"
    enum Key { static let idToken = "idToken"; static let refreshToken = "refreshToken"; static let userId = "userId"; static let email = "email" }

    static func saveString(_ value: String, key: String) {
        try? save(service: service, account: key, value: Data(value.utf8))
    }
    static func readString(_ key: String) -> String? {
        (try? read(service: service, account: key)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func deleteKey(_ key: String) { delete(service: service, account: key) }
    static func clearAll() {
        deleteKey(Key.idToken); deleteKey(Key.refreshToken); deleteKey(Key.userId); deleteKey(Key.email)
    }
}
