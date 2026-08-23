import Foundation
import LocalAuthentication
import Security

enum KeychainStore {
    private static let service = "com.mtglitch.MagicLoupe"
    /// New account so the ACL-bound login-keychain item is never touched again.
    private static let account = "openrouter-api-key.v2"
    private static let legacyAccount = "openrouter-api-key"

    static func save(apiKey: String) throws {
        let data = Data(apiKey.utf8)
        deleteSilently(account: account, dataProtection: true)
        deleteSilently(account: account, dataProtection: false)
        guard !apiKey.isEmpty else { return }

        if add(data, account: account, dataProtection: true) == errSecSuccess { return }
        let status = add(data, account: account, dataProtection: false)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load() throws -> String {
        if let value = copySilently(account: account, dataProtection: true) { return value }
        if let value = copySilently(account: account, dataProtection: false) { return value }
        if let value = copySilently(account: legacyAccount, dataProtection: true)
            ?? copySilently(account: legacyAccount, dataProtection: false)
        {
            try? save(apiKey: value)
            return value
        }
        return ""
    }

    private static func copySilently(account: String, dataProtection: Bool) -> String? {
        var query = baseQuery(account: account, dataProtection: dataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = silentAuth
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    @discardableResult
    private static func add(_ data: Data, account: String, dataProtection: Bool) -> OSStatus {
        var query = baseQuery(account: account, dataProtection: dataProtection)
        query[kSecValueData as String] = data
        query[kSecAttrLabel as String] = "Magic Loupe OpenRouter"
        if dataProtection {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        } else if let access = openFileBasedAccess() {
            query[kSecAttrAccess as String] = access
        }
        return SecItemAdd(query as CFDictionary, nil)
    }

    private static func deleteSilently(account: String, dataProtection: Bool) {
        var query = baseQuery(account: account, dataProtection: dataProtection)
        query[kSecUseAuthenticationContext as String] = silentAuth
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        SecItemDelete(query as CFDictionary)
    }

    private static var silentAuth: LAContext {
        let context = LAContext()
        context.interactionNotAllowed = true
        return context
    }

    private static func baseQuery(account: String, dataProtection: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    /// Login-keychain ACL that trusts any caller, so ad-hoc rebuilds do not re-prompt.
    private static func openFileBasedAccess() -> SecAccess? {
        var trusted: SecTrustedApplication?
        guard SecTrustedApplicationCreateFromPath(nil, &trusted) == errSecSuccess,
              let trusted
        else { return nil }
        var access: SecAccess?
        let status = SecAccessCreate(
            "Magic Loupe OpenRouter key" as CFString,
            [trusted] as CFArray,
            &access
        )
        guard status == errSecSuccess else { return nil }
        return access
    }

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .saveFailed(let s): "Не удалось сохранить ключ в Keychain (\(s))"
            case .loadFailed(let s): "Не удалось прочитать ключ из Keychain (\(s))"
            }
        }
    }
}
