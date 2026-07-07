import Foundation

/// Miroir minimal de `AppLocale` (macOS/iOS, `Localization/Localization.swift`) :
/// seule `Article.dateFormatted` en a besoin pour compiler côté tvOS, qui ne
/// réutilise pas le système de localisation complet (UI en français fixe).
enum AppLocale {
    static var identifier: String = "fr_FR"
}
