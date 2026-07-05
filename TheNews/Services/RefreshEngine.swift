import Foundation
import SwiftData

/// Logique de rafraîchissement partagée entre le refresh manuel, la tâche de fond
/// iOS (`BGAppRefreshTask`) et le rafraîchissement périodique macOS : télécharge
/// les rubriques abonnées, insère les nouveautés (dédupliquées), détecte celles qui
/// correspondent aux sujets de veille « à notifier » et émet les notifications.
@MainActor
enum RefreshEngine {

    /// Exécute un cycle complet. Renvoie le nombre de nouveaux articles correspondant
    /// à la veille. `notify` contrôle l'émission effective des notifications.
    @discardableResult
    static func run(container: ModelContainer, notify: Bool) async -> Int {
        let context = ModelContext(container)
        CustomFeedStore(context: context).reloadCatalog()
        let subscriptions = SubscriptionStore(context: context)
        try? subscriptions.seedIfNeeded()

        let feeds = (try? subscriptions.subscribedFeeds()) ?? []
        guard !feeds.isEmpty else { return 0 }

        let notifyTopics = (try? context.fetch(FetchDescriptor<WatchTopic>(
            predicate: #Predicate { $0.isEnabled && $0.notify }
        ))) ?? []

        let service = RSSService()
        let store = FeedStore(context: context)

        // Téléchargement/parsing en parallèle ; on ignore les rubriques en erreur.
        let results = await withTaskGroup(of: (String, [ParsedArticle])?.self) { group in
            for feed in feeds {
                group.addTask {
                    guard let parsed = try? await service.fetch(feed) else { return nil }
                    return (feed.id, parsed)
                }
            }
            var out: [(String, [ParsedArticle])] = []
            for await result in group { if let result { out.append(result) } }
            return out
        }

        var matched: [Article] = []
        for (feedID, parsed) in results {
            let inserted = (try? store.ingest(parsed, feedID: feedID)) ?? []
            if !notifyTopics.isEmpty {
                matched += inserted.filter { MatchingEngine.isMatch($0, topics: notifyTopics) }
            }
        }
        try? store.prune()

        if notify && !matched.isEmpty {
            await NotificationService.shared.notify(articles: matched)
        }
        return matched.count
    }
}
