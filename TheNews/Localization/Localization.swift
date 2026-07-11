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

// MARK: - Navigation par swipe (iOS)

/// Mode de navigation par swipe entre articles (détail iOS).
enum ArticleSwipeMode: String, CaseIterable, Identifiable {
    /// Passe à l'article suivant dans la liste (tous articles).
    case all
    /// Passe au prochain article **non lu** de la liste.
    case unread
    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .all:    return "swipe_all"
        case .unread: return "swipe_unread"
        }
    }
}

// MARK: - Configuration de la synthèse IA

enum DigestLength: String, CaseIterable, Identifiable {
    case concise, detailed
    var id: String { rawValue }
    var titleKey: String { self == .concise ? "digest_concise" : "digest_detailed" }
}

enum DigestFormat: String, CaseIterable, Identifiable {
    case bullets, paragraph
    var id: String { rawValue }
    var titleKey: String { self == .bullets ? "digest_bullets" : "digest_paragraph" }
}

enum DigestTone: String, CaseIterable, Identifiable {
    case neutral, explanatory, wire
    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .neutral:     return "digest_tone_neutral"
        case .explanatory: return "digest_tone_explanatory"
        case .wire:        return "digest_tone_wire"
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

    /// Briefing quotidien : notification récapitulative programmée chaque jour.
    var briefingEnabled: Bool {
        didSet { UserDefaults.standard.set(briefingEnabled, forKey: "briefingEnabled") }
    }
    /// Heure d'envoi du briefing (0–23), par défaut 8 h.
    var briefingHour: Int {
        didSet { UserDefaults.standard.set(briefingHour, forKey: "briefingHour") }
    }

    /// Mode de navigation par swipe entre articles (iOS).
    var swipeModeRaw: String {
        didSet { UserDefaults.standard.set(swipeModeRaw, forKey: "swipeMode") }
    }
    var swipeMode: ArticleSwipeMode { ArticleSwipeMode(rawValue: swipeModeRaw) ?? .all }

    /// Correspondance sémantique des sujets de veille (Foundation Models), en complément du
    /// matching lexical — off par défaut le temps de valider la pertinence perçue vs. le coût
    /// de latence (cf. `SemanticMatchingEngine`, `PLAN.md` Phase F1).
    var smartAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(smartAlertsEnabled, forKey: "smartAlertsEnabled") }
    }

    // MARK: Synthèse IA (configurable)
    var digestLengthRaw: String { didSet { UserDefaults.standard.set(digestLengthRaw, forKey: "digestLength") } }
    var digestFormatRaw: String { didSet { UserDefaults.standard.set(digestFormatRaw, forKey: "digestFormat") } }
    var digestToneRaw: String { didSet { UserDefaults.standard.set(digestToneRaw, forKey: "digestTone") } }
    var digestCount: Int { didSet { UserDefaults.standard.set(digestCount, forKey: "digestCount") } }

    var digestLength: DigestLength { DigestLength(rawValue: digestLengthRaw) ?? .concise }
    var digestFormat: DigestFormat { DigestFormat(rawValue: digestFormatRaw) ?? .bullets }
    var digestTone: DigestTone { DigestTone(rawValue: digestToneRaw) ?? .neutral }

    init() {
        appearanceRaw = UserDefaults.standard.string(forKey: "appearance") ?? AppearanceMode.system.rawValue
        languageRaw = UserDefaults.standard.string(forKey: "language") ?? AppLanguage.system.rawValue
        apiKey = Keychain.get(account: "api-key") ?? ""
        briefingEnabled = UserDefaults.standard.bool(forKey: "briefingEnabled")
        briefingHour = UserDefaults.standard.object(forKey: "briefingHour") as? Int ?? 8
        swipeModeRaw = UserDefaults.standard.string(forKey: "swipeMode") ?? ArticleSwipeMode.all.rawValue
        smartAlertsEnabled = UserDefaults.standard.bool(forKey: "smartAlertsEnabled")
        digestLengthRaw = UserDefaults.standard.string(forKey: "digestLength") ?? DigestLength.concise.rawValue
        digestFormatRaw = UserDefaults.standard.string(forKey: "digestFormat") ?? DigestFormat.bullets.rawValue
        digestToneRaw = UserDefaults.standard.string(forKey: "digestTone") ?? DigestTone.neutral.rawValue
        digestCount = UserDefaults.standard.object(forKey: "digestCount") as? Int ?? 25
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
