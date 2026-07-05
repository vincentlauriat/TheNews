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

        var errorDescription: String? {
            switch self {
            case .invalidURL:  return "URL invalide."
            case .unreachable: return "Flux injoignable."
            case .notRSS:      return "Aucun article RSS trouvé à cette adresse."
            }
        }
    }

    /// Vérifie qu'une URL pointe vers un flux RSS lisible (≥ 1 article).
    /// `nonisolated` : le fetch réseau n'a pas besoin du `MainActor`.
    nonisolated static func validate(urlString: String) async throws {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            throw ValidationError.invalidURL
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
