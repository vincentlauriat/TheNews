import Foundation
import SwiftData
import WidgetKit

/// Publie les instantanés consommés par les extensions (App Group) : reprend la
/// sélection du briefing (top sujets récents, dédupliqués cross-source) pour le
/// widget WidgetKit (texte seul, 6 articles) **et** pour l'écran de veille
/// (`TheNewsScreenSaver`, avec image + chapô, jusqu'à 12). Appelé après chaque
/// rafraîchissement.
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

        let briefing = BriefingEngine.today(context: context)
        let briefingItems = briefing.map { article in
            BriefingSnapshotArticle(
                id: article.id,
                title: article.title,
                summary: article.summary,
                source: article.feed?.source?.name ?? "TheNews",
                imageURL: article.imageURL,
                publishedAt: article.publishedAt
            )
        }
        BriefingSnapshotStore.write(BriefingSnapshot(articles: briefingItems, generatedAt: Date()))
    }
}
