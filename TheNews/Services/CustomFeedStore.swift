import Foundation
import SwiftData

/// Gère les flux RSS personnalisés : persistance SwiftData, validation réseau à
/// l'ajout, et synchronisation du cache `Feed.customCatalog` qui alimente le
/// catalogue dynamique. Opère sur le `MainActor` (manipule le `ModelContext` et
/// met à jour le cache statique lu par les vues).
@MainActor
struct CustomFeedStore {
    let context: ModelContext

    /// Flux perso, du plus ancien au plus récent.
    func all() throws -> [CustomFeed] {
        try context.fetch(FetchDescriptor<CustomFeed>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    /// Recharge le cache `Feed.customCatalog` depuis SwiftData. À appeler au
    /// démarrage et après toute modification.
    func reloadCatalog() {
        Feed.customCatalog = ((try? all()) ?? []).compactMap(\.asFeed)
    }

    /// Ajoute un flux perso, l'abonne aussitôt (pour qu'il apparaisse dans la
    /// sidebar) et rafraîchit le cache. Renvoie le flux créé.
    @discardableResult
    func add(title: String, urlString: String, symbol: String = "dot.radiowaves.up.forward") throws -> CustomFeed {
        // Garde dur : sans lui, un flux déjà servi par le catalogue intégré apparaît
        // deux fois dans la sidebar (sous sa source **et** sous « Mes flux »), et ses
        // articles se retrouvent rattachés à l'une ou l'autre entrée selon l'ordre
        // d'ingestion — `FeedStore.ingest` déduplique par `guid` toutes rubriques
        // confondues, donc la seconde n'en reçoit aucun et paraît vide.
        if let builtIn = Self.builtInFeed(matching: urlString) {
            throw ValidationError.alreadyInCatalog(builtIn.title)
        }
        let feed = CustomFeed(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            urlString: urlString.trimmingCharacters(in: .whitespacesAndNewlines),
            symbol: symbol
        )
        context.insert(feed)
        context.insert(FeedSubscription(feedID: feed.id))
        try context.save()
        reloadCatalog()
        return feed
    }

    /// Modifie un flux perso et rafraîchit le cache dynamique.
    func update(_ feed: CustomFeed, title: String, urlString: String) throws {
        feed.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        feed.urlString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        try context.save()
        reloadCatalog()
    }

    /// Supprime un flux perso, son abonnement et ses articles en cache.
    func remove(_ feed: CustomFeed) throws {
        let feedID = feed.id
        if let sub = try context.fetch(FetchDescriptor<FeedSubscription>(
            predicate: #Predicate { $0.feedID == feedID }
        )).first {
            context.delete(sub)
        }
        for article in try context.fetch(FetchDescriptor<Article>(
            predicate: #Predicate { $0.feedID == feedID }
        )) {
            context.delete(article)
        }
        context.delete(feed)
        try context.save()
        reloadCatalog()
    }

    // MARK: - Validation réseau

    enum ValidationError: LocalizedError {
        case invalidURL
        case unreachable
        case notRSS
        case alreadyInCatalog(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:  return "URL invalide."
            case .unreachable: return "Flux injoignable."
            case .notRSS:      return "Aucun article RSS trouvé à cette adresse."
            case .alreadyInCatalog(let title):
                return "Ce flux fait déjà partie du catalogue intégré (« \(title) »). Active-le depuis la sidebar plutôt que de l'ajouter en flux perso."
            }
        }
    }

    /// Rubrique du catalogue intégré servant déjà cette URL, s'il y en a une.
    ///
    /// La comparaison passe par `feedKey` plutôt que par `ParsedArticle.canonicalLink` :
    /// ce dernier retire la requête, ce qui est juste pour un lien d'article (paramètres
    /// de suivi) mais faux pour une URL de flux, où `?format=rss` désigne une autre
    /// ressource.
    nonisolated static func builtInFeed(matching urlString: String) -> Feed? {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let key = feedKey(url)
        else { return nil }
        return Feed.builtInCatalog.first { feedKey($0.rssURL) == key }
    }

    /// Clé de comparaison de deux URLs de flux : hôte insensible à la casse, `http` et
    /// `https` équivalents (le même flux est souvent publié sous les deux), slash final
    /// et fragment ignorés. Le chemin garde sa casse — il peut être significatif.
    nonisolated private static func feedKey(_ url: URL) -> String? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        guard let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        components.scheme = "https"
        components.host = components.host?.lowercased()
        components.fragment = nil
        if components.path.hasSuffix("/") && components.path.count > 1 {
            components.path.removeLast()
        }
        return components.url?.absoluteString
    }

    /// Vérifie qu'une URL pointe vers un flux RSS lisible (≥ 1 article).
    /// `nonisolated` : le fetch réseau n'a pas besoin du `MainActor`.
    nonisolated static func validate(urlString: String) async throws {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            throw ValidationError.invalidURL
        }
        // Vérifié avant le réseau : inutile de télécharger un flux qu'on refusera.
        if let builtIn = builtInFeed(matching: trimmed) {
            throw ValidationError.alreadyInCatalog(builtIn.title)
        }
        let probe = Feed(id: "probe", sourceID: Source.custom.id, title: "probe", symbol: "", rssURL: url)
        let articles: [ParsedArticle]
        do {
            articles = try await RSSService().fetch(probe)
        } catch {
            throw ValidationError.unreachable
        }
        guard !articles.isEmpty else { throw ValidationError.notRSS }
    }
}
