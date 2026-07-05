import Foundation
import Security

/// Stockage sécurisé d'un secret (clés API, tokens…) dans le trousseau.
/// Les valeurs ne sont jamais affichées ni loggées. Le `service` est dérivé du
/// bundle identifier pour isoler les entrées de cette app.
enum Keychain {
    private static let service = Bundle.main.bundleIdentifier ?? "fr.vincentlauriat.thenews"

    static func set(_ value: String?, account: String) {
        // On supprime toujours l'entrée existante avant d'en réécrire une.
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)

        guard let value, !value.isEmpty, let data = value.data(using: .utf8) else { return }
        var attrs = base
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
