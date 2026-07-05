import SwiftUI
import Observation

// MARK: - Apparence

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
    var titleKey: String {
        switch self {
        case .system: return "appearance_system"
        case .light:  return "appearance_light"
        case .dark:   return "appearance_dark"
        }
    }
}

// MARK: - Langue

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, fr, en
    var id: String { rawValue }

    /// Libellé affiché dans le sélecteur (langues dans leur propre graphie).
    var nativeName: String {
        switch self {
        case .system: return ""          // remplacé par la chaîne localisée "language_system"
        case .fr:     return "Français"
        case .en:     return "English"
        }
    }
}

/// Identifiant de locale courant, lu par les modèles (formatage de dates)
/// sans dépendance directe à l'environnement SwiftUI.
enum AppLocale {
    static var identifier: String = "en_US"
}

// MARK: - Réglages observables

@Observable
@MainActor
final class AppSettings {
    var appearanceRaw: String {
        didSet { UserDefaults.standard.set(appearanceRaw, forKey: "appearance") }
    }
    var languageRaw: String {
        didSet {
            UserDefaults.standard.set(languageRaw, forKey: "language")
            AppLocale.identifier = localeIdentifier
        }
    }

    /// Exemple de secret stocké dans le Keychain (jamais en clair dans UserDefaults).
    /// Remplace / supprime selon tes besoins — sert de patron pour tes propres clés API.
    var apiKey: String {
        didSet { Keychain.set(apiKey, account: "api-key") }
    }

    var apiKeyConfigured: Bool { !apiKey.isEmpty }

    init() {
        appearanceRaw = UserDefaults.standard.string(forKey: "appearance") ?? AppearanceMode.system.rawValue
        languageRaw = UserDefaults.standard.string(forKey: "language") ?? AppLanguage.system.rawValue
        apiKey = Keychain.get(account: "api-key") ?? ""
        AppLocale.identifier = localeIdentifier
    }

    var appearance: AppearanceMode { AppearanceMode(rawValue: appearanceRaw) ?? .system }
    var language: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .system }

    /// Code langue effectif (résout `.system` via les préférences de l'OS).
    var effectiveLang: String {
        if language == .system {
            let pref = Locale.preferredLanguages.first ?? "en"
            if pref.hasPrefix("fr") { return "fr" }
            return "en"
        }
        return language.rawValue
    }

    var localeIdentifier: String {
        switch effectiveLang {
        case "fr": return "fr_FR"
        default:   return "en_US"
        }
    }

    // MARK: Traduction

    func t(_ key: String) -> String {
        let lang = effectiveLang
        return Strings.table[lang]?[key]
            ?? Strings.table["en"]?[key]
            ?? key
    }

    /// Compteur avec unité pluralisée : « 3 items », « 1 item »…
    func count(_ n: Int, _ oneKey: String, _ manyKey: String) -> String {
        let unit = t(n <= 1 ? oneKey : manyKey)
        return "\(n) \(unit)"
    }
}
