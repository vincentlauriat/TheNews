import Foundation

struct WatchFeedConfiguration: Equatable, Sendable {
    static let storageKey = "watchFeedIDs"
    static let contextKey = "watchFeedIDs"
    static let didChangeNotification = Notification.Name("WatchFeedConfigurationDidChange")

    static let defaultFeedIDs = ["lemonde.une", "lesechos.economie"]

    /// Doit rester le miroir exact de `Feed.builtInCatalog` : le pendant watchOS de
    /// ce type dérive sa liste des catalogues (`Feed.availableFeeds`), et les deux
    /// `sanitizedFeedIDs` écartent silencieusement ce que l'autre côté autorise —
    /// une divergence ne produirait pas d'erreur, juste un flux qui n'arrive jamais
    /// sur la montre. Verrouillé par `WatchFeedConfigurationTests`.
    static let allowedFeedIDs: Set<String> = [
        "lemonde.une",
        "lemonde.international",
        "lemonde.politique",
        "lemonde.societe",
        "lemonde.economie",
        "lemonde.idees",
        "lemonde.planete",
        "lemonde.sciences",
        "lemonde.pixels",
        "lemonde.culture",
        "lemonde.sport",
        "lesechos.economie",
        "lesechos.entreprises",
        "lesechos.finance",
        "lesechos.monde",
        "lesechos.politique",
        "lesechos.idees",
        "lesechos.patrimoine",
        "lesechos.weekend",
        "lesechos.elections",
        "lopinion.politique",
        "lopinion.international",
        "lopinion.economie",
        "lopinion.business",
        "lopinion.opinions",
        "lopinion.edito",
        "lopinion.patrimoine",
        "lopinion.weekend",
        "calipia.blog",
        "calipia.ia",
        "calipia.securite",
        "calipia.os",
        "calipia.materiel",
        "calipia.productivite",
        "calipia.administration"
    ]

    static func sanitizedFeedIDs(_ ids: [String]) -> [String] {
        var seen: Set<String> = []
        let sanitized = ids.compactMap { id -> String? in
            guard allowedFeedIDs.contains(id), !seen.contains(id) else { return nil }
            seen.insert(id)
            return id
        }
        return sanitized.isEmpty ? defaultFeedIDs : sanitized
    }

    static func load(from defaults: UserDefaults = .standard) -> [String] {
        sanitizedFeedIDs(defaults.stringArray(forKey: storageKey) ?? defaultFeedIDs)
    }

    static func save(_ ids: [String], to defaults: UserDefaults = .standard) {
        defaults.set(sanitizedFeedIDs(ids), forKey: storageKey)
    }
}
