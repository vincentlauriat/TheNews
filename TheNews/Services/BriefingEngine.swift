import Foundation
import SwiftData

/// Construit le « briefing du jour » : une sélection condensée des sujets marquants
/// des dernières 24 h parmi les rubriques suivies. Priorise les articles qui
/// correspondent aux sujets de veille, puis **déduplique cross-source** (un même
/// sujet couvert par plusieurs journaux n'apparaît qu'une fois) pour livrer un
/// vrai résumé de l'actualité plutôt qu'un flux brut. 100 % on-device.
@MainActor
enum BriefingEngine {

    /// Articles du briefing, du plus pertinent au moins pertinent (veille d'abord).
    static func today(context: ModelContext, within hours: Int = 24, limit: Int = 12) -> [Article] {
        let ids = Set((try? SubscriptionStore(context: context).subscribedFeedIDs()) ?? [])
        guard !ids.isEmpty else { return [] }

        let cutoff = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? .distantPast
        let recent = (try? context.fetch(FetchDescriptor<Article>(
            predicate: #Predicate { $0.publishedAt >= cutoff && ids.contains($0.feedID) },
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        ))) ?? []
        guard !recent.isEmpty else { return [] }

        // Priorité aux articles correspondant à un sujet de veille actif.
        let topics = (try? context.fetch(FetchDescriptor<WatchTopic>(
            predicate: #Predicate { $0.isEnabled }
        ))) ?? []
        let watched = topics.isEmpty ? [] : recent.filter { MatchingEngine.isMatch($0, topics: topics) }
        let watchedIDs = Set(watched.map(\.id))
        let ordered = watched + recent.filter { !watchedIDs.contains($0.id) }

        // Dédup cross-source : on ne garde qu'un article par sujet (forte similarité).
        var kept: [Article] = []
        var keptTokens: [Set<String>] = []
        for article in ordered {
            let tokens = RelatedArticlesEngine.tokens(article.title + " " + article.summary)
            let duplicate = keptTokens.contains { RelatedArticlesEngine.similarity($0, tokens) >= 0.5 }
            if duplicate { continue }
            kept.append(article)
            keptTokens.append(tokens)
            if kept.count >= limit { break }
        }
        return kept
    }
}
