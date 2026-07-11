import Foundation

/// Sélection légère et autonome du Briefing pour l'écran de veille : récupère les
/// flux RSS **directement**, comme `TheNewsWatch`. Nécessaire car le process hôte
/// `legacyScreenSaver` (macOS Sequoia+) bloque silencieusement l'accès à l'App
/// Group partagé avec l'app principale (« App Group Container Protection » —
/// le host ne peut pas répondre au prompt système que ce contrôle exigerait),
/// donc pas d'accès aux abonnements personnels de l'utilisateur non plus : on
/// prend un petit sous-ensemble représentatif du catalogue plutôt que les
/// rubriques réellement suivies.
@MainActor
enum AutonomousBriefing {
    private static let feedIDs = ["lemonde.une", "lemonde.international", "lesechos.economie", "lesechos.monde"]

    static func today(limit: Int = 12) async -> [BriefingSnapshotArticle] {
        let feeds = feedIDs.compactMap(Feed.byID)
        let service = RSSService()

        var collected: [(feed: Feed, article: ParsedArticle)] = []
        await withTaskGroup(of: [(Feed, ParsedArticle)].self) { group in
            for feed in feeds {
                group.addTask {
                    let parsed = (try? await service.fetch(feed)) ?? []
                    return parsed.map { (feed, $0) }
                }
            }
            for await batch in group { collected += batch }
        }

        let ordered = collected.sorted { $0.article.publishedAt > $1.article.publishedAt }

        // Dédup cross-source (même principe que `BriefingEngine.today`/
        // `RelatedArticlesEngine` côté app, réimplémenté ici en local : ces deux
        // fichiers dépendent de `Article`/`WatchTopic` SwiftData, absents de cette
        // cible autonome — même compromis que `TheNewsWatch`/`TheNewsTV` en E1).
        var kept: [(feed: Feed, article: ParsedArticle)] = []
        var keptTokens: [Set<String>] = []
        for entry in ordered {
            let tokens = Self.tokens(entry.article.title + " " + entry.article.summary)
            let duplicate = keptTokens.contains { Self.similarity($0, tokens) >= 0.5 }
            if duplicate { continue }
            kept.append(entry)
            keptTokens.append(tokens)
            if kept.count >= limit { break }
        }

        return kept.map { feed, article in
            BriefingSnapshotArticle(
                id: article.id,
                title: article.title,
                summary: article.summary,
                source: feed.source?.name ?? "TheNews",
                imageURL: article.imageURL,
                publishedAt: article.publishedAt
            )
        }
    }

    // MARK: - Dédup (copie locale minimale de RelatedArticlesEngine.tokens/similarity)

    private static let stopWords: Set<String> = [
        "avec", "dans", "pour", "plus", "sans", "sont", "cette", "leur", "leurs", "elle",
        "elles", "nous", "vous", "mais", "donc", "chez", "entre", "aussi", "apres", "avant",
        "contre", "selon", "tout", "tous", "toute", "toutes", "encore", "depuis", "vers",
        "être", "etre", "fait", "faire", "deux", "trois", "cent", "mille", "ans", "an",
        "with", "from", "that", "this", "have", "will", "your", "they", "their", "them",
        "about", "into", "over", "after", "before", "than", "then", "there", "what", "when",
        "which", "while", "would", "could", "should", "been", "were", "also", "more", "most",
    ]

    private static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr"))
    }

    private static func tokens(_ text: String) -> Set<String> {
        let norm = normalize(text)
        let parts = norm.split { !$0.isLetter && !$0.isNumber }
        return Set(parts.map(String.init).filter { $0.count >= 4 && !stopWords.contains($0) })
    }

    private static func similarity(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let inter = a.intersection(b).count
        guard inter >= 2 else { return 0 }
        let union = a.union(b).count
        return union > 0 ? Double(inter) / Double(union) : 0
    }
}
