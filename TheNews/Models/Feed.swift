import Foundation

/// Une rubrique d'une `Source` exposée en RSS (ex. « À la une », « Finance & Marchés »).
/// C'est une description statique (identité + URL du flux) ; l'état d'abonnement et
/// d'alerte de l'utilisateur est stocké à part (`FeedSubscription`) pour garder le
/// catalogue immuable et versionnable dans le code.
struct Feed: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let sourceID: String
    let title: String
    /// Nom court d'icône SF Symbols pour la sidebar.
    let symbol: String
    let rssURL: URL

    var source: Source? { Source.byID(sourceID) }
}

extension Feed {
    // MARK: - Le Monde

    /// Fabrique une rubrique Le Monde à partir de son slug de flux.
    private static func leMonde(_ id: String, _ title: String, _ symbol: String, _ path: String) -> Feed {
        Feed(
            id: "lemonde.\(id)",
            sourceID: Source.leMonde.id,
            title: title,
            symbol: symbol,
            rssURL: URL(string: "https://www.lemonde.fr/\(path)")!
        )
    }

    /// Catalogue des flux RSS publics de Le Monde.
    /// « Une » utilise `rss/une.xml` ; les rubriques utilisent `<rubrique>/rss_full.xml`.
    static let leMondeCatalog: [Feed] = [
        leMonde("une",           "À la une",       "newspaper",              "rss/une.xml"),
        leMonde("international",  "International",  "globe",                  "international/rss_full.xml"),
        leMonde("politique",     "Politique",      "building.columns",       "politique/rss_full.xml"),
        leMonde("societe",       "Société",        "person.3",               "societe/rss_full.xml"),
        leMonde("economie",      "Économie",       "chart.line.uptrend.xyaxis", "economie/rss_full.xml"),
        leMonde("idees",         "Idées",          "text.bubble",            "idees/rss_full.xml"),
        leMonde("planete",       "Planète",        "leaf",                   "planete/rss_full.xml"),
        leMonde("sciences",      "Sciences",       "atom",                   "sciences/rss_full.xml"),
        leMonde("pixels",        "Pixels (Tech)",  "cpu",                    "pixels/rss_full.xml"),
        leMonde("culture",       "Culture",        "theatermasks",           "culture/rss_full.xml"),
        leMonde("sport",         "Sport",          "figure.run",             "sport/rss_full.xml"),
    ]

    // MARK: - Les Echos

    /// Fabrique une rubrique Les Echos à partir de son slug de flux officiel.
    /// Flux publics listés sur `https://www.lesechos.fr/rss/`, servis par
    /// `https://services.lesechos.fr/rss/<slug>.xml` (RSS 2.0 : titre, chapô,
    /// lien direct, `guid` stable et image `media:content`).
    private static func lesEchos(_ id: String, _ title: String, _ symbol: String, _ slug: String) -> Feed {
        Feed(
            id: "lesechos.\(id)",
            sourceID: Source.lesEchos.id,
            title: title,
            symbol: symbol,
            rssURL: URL(string: "https://services.lesechos.fr/rss/\(slug).xml")!
        )
    }

    /// Catalogue des flux RSS officiels de Les Echos (source : page /rss/ du site).
    static let lesEchosCatalog: [Feed] = [
        lesEchos("economie",     "Économie",           "chart.line.uptrend.xyaxis", "les-echos-economie"),
        lesEchos("entreprises",  "Entreprises",        "building.2",                "les-echos-entreprises"),
        lesEchos("finance",      "Finance & Marchés",  "chart.bar",                 "les-echos-finance-marches"),
        lesEchos("monde",        "Monde",              "globe",                     "les-echos-monde"),
        lesEchos("politique",    "Politique",          "building.columns",          "les-echos-politique"),
        lesEchos("idees",        "Idées & Débats",     "text.bubble",               "les-echos-idees"),
        lesEchos("patrimoine",   "Patrimoine",         "banknote",                  "les-echos-patrimoine"),
        lesEchos("weekend",      "Week-end",           "sparkles",                  "les-echos-weekend"),
        lesEchos("elections",    "Élections",          "checkmark.seal",            "elections"),
    ]

    // MARK: - Catalogue combiné (multi-source, dynamique)

    /// Rubriques intégrées en dur (journaux fournis avec l'app).
    static let builtInCatalog: [Feed] = leMondeCatalog + lesEchosCatalog

    /// Flux ajoutés par l'utilisateur (`CustomFeed`), mis en cache pour un accès
    /// synchrone depuis `byID`/`catalog`. Rechargé par `CustomFeedStore.reloadCatalog()`
    /// au démarrage et à chaque ajout/suppression. Muté uniquement sur le `MainActor`
    /// (tous les consommateurs du catalogue le sont : vues, FeedStore, RefreshEngine).
    static var customCatalog: [Feed] = []

    /// Toutes les rubriques de toutes les sources (intégrées + perso).
    static var catalog: [Feed] { builtInCatalog + customCatalog }

    /// Rubriques d'une source donnée, dans l'ordre du catalogue.
    static func feeds(for sourceID: String) -> [Feed] {
        catalog.filter { $0.sourceID == sourceID }
    }

    /// Catalogue groupé par source, dans l'ordre de `Source.all` — pour la sidebar
    /// et l'écran de gestion, qui présentent une section par journal.
    static var bySource: [(source: Source, feeds: [Feed])] {
        Source.all.map { ($0, feeds(for: $0.id)) }.filter { !$0.1.isEmpty }
    }

    /// Rubrique par défaut affichée au premier lancement (la « Une » du Monde).
    static var frontPage: Feed { leMondeCatalog[0] }

    static func byID(_ id: String) -> Feed? { catalog.first { $0.id == id } }
}
