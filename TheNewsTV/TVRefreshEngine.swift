import Foundation
import SwiftData

/// Rafraîchissement tvOS : ingère les rubriques abonnées dans SwiftData, dont
/// l'état (abonnements, favoris, flux perso) est partagé via iCloud avec
/// macOS/iOS (Phase E2). Version allégée de `RefreshEngine` (macOS/iOS) : pas
/// de notifications ni de publication widget, non pertinentes sur tvOS.
@MainActor
enum TVRefreshEngine {
    @discardableResult
    static func run(container: ModelContainer) async -> Int {
        let context = ModelContext(container)
        CustomFeedStore(context: context).reloadCatalog()
        try? SubscriptionStore(context: context).seedIfNeeded()

        let feeds = (try? SubscriptionStore(context: context).subscribedFeeds()) ?? []
        guard !feeds.isEmpty else { return 0 }

        let service = RSSService()
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

        let store = FeedStore(context: context)
        var insertedCount = 0
        for (feedID, parsed) in results {
            insertedCount += (try? store.ingest(parsed, feedID: feedID))?.count ?? 0
        }
        try? store.prune()
        return insertedCount
    }
}
