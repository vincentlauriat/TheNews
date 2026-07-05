import Foundation
import SwiftData
import WidgetKit

/// Publie l'instantané consommé par le widget : reprend la sélection du briefing
/// (top sujets récents, dédupliqués cross-source), l'écrit dans l'App Group et
/// demande le rechargement des timelines. Appelé après chaque rafraîchissement.
@MainActor
enum WidgetPublisher {
    static func publish(context: ModelContext, limit: Int = 6) {
        let articles = BriefingEngine.today(context: context, limit: limit)
        let items = articles.map { article in
            WidgetArticle(
                id: article.id,
                title: article.title,
                source: article.feed?.source?.name ?? "TheNews",
                sectionTitle: article.feed?.title ?? "",
                publishedAt: article.publishedAt
            )
        }
        WidgetSnapshotStore.write(WidgetSnapshot(articles: items, generatedAt: Date()))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
