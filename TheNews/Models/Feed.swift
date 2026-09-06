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

    // MARK: - L'Opinion

    /// Fabrique une rubrique L'Opinion. Le site sert ses flux à la racine : `index.rss`
    /// pour la une, `<section>.rss` pour chaque rubrique (RSS 2.0 avec `media:content`).
    private static func lopinion(_ id: String, _ title: String, _ symbol: String, _ path: String) -> Feed {
        Feed(
            id: "lopinion.\(id)",
            sourceID: Source.lopinion.id,
            title: title,
            symbol: symbol,
            rssURL: URL(string: "https://www.lopinion.fr/\(path)")!
        )
    }

    /// Catalogue des flux RSS publics de L'Opinion.
    ///
    /// Bâti sur les sections réelles du site (`<section>.rss`), pas sur la famille
    /// `<thème>/index.rss` qui existe en parallèle : celle-ci agrège des articles déjà
    /// couverts par les sections (« Tech » et « Entreprises » sont à 80 % de l'Économie)
    /// et ferait doublon sans rien apporter.
    ///
    /// Le flux racine `index.rss` est volontairement absent, bien qu'il soit le flux
    /// « officiel » du site : ses 250 entrées **sont** les neuf sections réunies. Or un
    /// article n'est stocké qu'une fois, sous la rubrique qui l'a ingéré la première, et
    /// `RefreshEngine` ingère dans l'ordre d'arrivée réseau (`withTaskGroup`), pas dans
    /// celui du catalogue : servir le flux racine à côté de ses propres sous-ensembles
    /// rendrait le contenu des rubriques non déterministe d'un rafraîchissement à
    /// l'autre. Les neuf sections couvrent le site plus finement de toute façon —
    /// `patrimoine.rss` publie 28 articles absents de `index.rss`.
    static let lopinionCatalog: [Feed] = [
        lopinion("politique",     "Politique",           "building.columns",          "politique.rss"),
        lopinion("international", "International",       "globe",                     "international.rss"),
        lopinion("economie",      "Économie",            "chart.line.uptrend.xyaxis", "economie.rss"),
        lopinion("business",      "L'Opinion Business",  "building.2",                "l-opinion-business.rss"),
        lopinion("opinions",      "Opinions",            "text.bubble",               "opinions.rss"),
        lopinion("edito",         "Édito",               "text.quote",                "edito.rss"),
        lopinion("patrimoine",    "Patrimoine",          "banknote",                  "patrimoine.rss"),
        lopinion("weekend",       "'O2 week-end",        "sparkles",                  "o2-week-end.rss"),
    ]

    // MARK: - Calipia

    /// Fabrique une rubrique Calipia. Le blog tourne sous WordPress : la « une »
    /// est le flux racine `/feed/`, les rubriques les flux de catégorie
    /// `/category/<slug>/feed/`.
    private static func calipia(_ id: String, _ title: String, _ symbol: String, _ path: String) -> Feed {
        Feed(
            id: "calipia.\(id)",
            sourceID: Source.calipia.id,
            title: title,
            symbol: symbol,
            rssURL: URL(string: "https://blog.calipia.com/\(path)")!
        )
    }

    /// Catalogue des flux du blog Calipia.
    ///
    /// Les catégories « Actualité » et « Divers » du blog ne sont volontairement pas
    /// reprises : la première couvre la quasi-totalité des billets (elle ferait
    /// doublon avec « Le blog »), la seconde est un fourre-tout sans valeur
    /// éditoriale. Les deux restent disponibles en flux perso si besoin.
    static let calipiaCatalog: [Feed] = [
        calipia("blog",           "Le blog",        "newspaper",       "feed/"),
        calipia("ia",             "IA",             "brain",           "category/ia/feed/"),
        calipia("securite",       "Sécurité",       "lock.shield",     "category/securite/feed/"),
        calipia("os",             "OS",             "desktopcomputer", "category/os/feed/"),
        calipia("materiel",       "Matériel",       "laptopcomputer",  "category/materiel/feed/"),
        calipia("productivite",   "Productivité",   "checklist",       "category/productivite/feed/"),
        calipia("administration", "Administration", "gearshape.2",     "category/administration/feed/"),
    ]

    // MARK: - Catalogue combiné (multi-source, dynamique)

    /// Rubriques intégrées en dur (journaux fournis avec l'app).
    static let builtInCatalog: [Feed] = leMondeCatalog + lesEchosCatalog + lopinionCatalog + calipiaCatalog

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
