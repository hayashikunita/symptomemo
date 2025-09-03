import Foundation
import Security

private let keychainService = "symptomemo.ai"

enum KeychainHelper {
    static func save(key: String, value: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        // まず追加を試みる
        var status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            // 既存がある場合は更新
            let find: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: key
            ]
            let attrs: [String: Any] = [kSecValueData as String: value]
            status = SecItemUpdate(find as CFDictionary, attrs as CFDictionary)
        }
        if status == errSecSuccess { return true }
        // Keychainに保存できない場合はフォールバック
        let defaultsKey = fallbackKey(for: key)
        UserDefaults.standard.set(value, forKey: defaultsKey)
        return UserDefaults.standard.synchronize()
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return data
        }
        // フォールバックから読み込み
        let defaultsKey = fallbackKey(for: key)
        return UserDefaults.standard.data(forKey: defaultsKey)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        // フォールバックも削除
        let defaultsKey = fallbackKey(for: key)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private static func fallbackKey(for key: String) -> String {
        return "kc." + keychainService + "." + key
    }
}

enum AIKeyStore {
    private static let account = "openai"

    static func setAPIKey(_ key: String?) {
        if let key, !key.isEmpty {
            _ = KeychainHelper.save(key: account, value: Data(key.utf8))
        } else {
            KeychainHelper.delete(key: account)
        }
    }

    static func getAPIKey() -> String? {
        guard let data = KeychainHelper.load(key: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
