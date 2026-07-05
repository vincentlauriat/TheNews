import Foundation
import SwiftData

/// Gère les abonnements aux rubriques : seeding initial, lecture, (dé)abonnement,
/// et bascule des alertes par rubrique. Opère sur le `MainActor` (ModelContext).
@MainActor
struct SubscriptionStore {
    let context: ModelContext

    /// Rubriques abonnées par défaut au tout premier lancement — un mix des deux
    /// journaux pour illustrer d'emblée l'agrégation multi-source.
    static let defaultFeedIDs = [
        "lemonde.une",
        "lemonde.international",
        "lemonde.economie",
        "lesechos.economie",
        "lesechos.finance",
        "lesechos.entreprises",
    ]

    /// Crée les abonnements par défaut si l'utilisateur n'en a aucun.
    func seedIfNeeded() throws {
        let count = try context.fetchCount(FetchDescriptor<FeedSubscription>())
        guard count == 0 else { return }
        for id in Self.defaultFeedIDs { context.insert(FeedSubscription(feedID: id)) }
        try context.save()
    }

    func all() throws -> [FeedSubscription] {
        try context.fetch(FetchDescriptor<FeedSubscription>())
    }

    /// Identifiants des rubriques abonnées, ordonnés selon le catalogue.
    func subscribedFeedIDs() throws -> [String] {
        let ids = Set(try all().map(\.feedID))
        return Feed.catalog.map(\.id).filter { ids.contains($0) }
    }

    /// Rubriques abonnées (objets `Feed`), ordonnées selon le catalogue.
    func subscribedFeeds() throws -> [Feed] {
        try subscribedFeedIDs().compactMap(Feed.byID)
    }

    func subscription(for feedID: String) throws -> FeedSubscription? {
        try context.fetch(FetchDescriptor<FeedSubscription>(
            predicate: #Predicate { $0.feedID == feedID }
        )).first
    }

    func isSubscribed(_ feedID: String) throws -> Bool {
        try subscription(for: feedID) != nil
    }

    /// Abonne ou désabonne à une rubrique. Renvoie l'état résultant (abonné ?).
    @discardableResult
    func toggle(_ feedID: String) throws -> Bool {
        if let existing = try subscription(for: feedID) {
            context.delete(existing)
            try context.save()
            return false
        } else {
            context.insert(FeedSubscription(feedID: feedID))
            try context.save()
            return true
        }
    }

    func setAlerts(_ enabled: Bool, for feedID: String) throws {
        guard let sub = try subscription(for: feedID) else { return }
        sub.alertsEnabled = enabled
        try context.save()
    }
}
