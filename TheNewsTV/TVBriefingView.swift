import SwiftUI

/// Briefing du jour, léger et autonome : agrège tout le catalogue en direct,
/// garde les dernières 24 h (repli sur tout si rien de récent) et déduplique
/// les sujets couverts par plusieurs sources. Réimplémente une version minimale
/// (tokens + similarité de Jaccard) de `RelatedArticlesEngine`/`BriefingEngine`
/// plutôt que de les réutiliser : ceux-ci dépendent de SwiftData/abonnements
/// persistés, hors périmètre de cette version tvOS « lite » (voir PLAN.md E1/E2).
struct TVBriefingView: View {
    @State private var articles: [TVArticle] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if loading && articles.isEmpty {
                ProgressView("Chargement…")
            } else if let errorMessage, articles.isEmpty {
                ContentUnavailableView("Briefing indisponible", systemImage: "wifi.slash",
                                       description: Text(errorMessage))
            } else if articles.isEmpty {
                ContentUnavailableView("Aucun article", systemImage: "tray")
            } else {
                List(Array(articles.enumerated()), id: \.element.id) { index, article in
                    NavigationLink(value: TVArticleSelection(articles: articles, index: index)) {
                        TVArticleRow(article: article)
                    }
                }
            }
        }
        .navigationTitle("Briefing")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        let fetched = await TVArticle.fetch(from: Feed.builtInCatalog)
        let cutoff = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? .distantPast
        let recent = fetched.filter { $0.publishedAt >= cutoff }
        articles = Self.dedup(recent.isEmpty ? fetched : recent, limit: 20)
        if articles.isEmpty { errorMessage = "Impossible de charger les flux." }
        loading = false
    }

    /// Ne garde qu'un article par sujet (≥ 2 mots forts communs, seuil 0.5),
    /// pour éviter que le même événement apparaisse une fois par source.
    private static func dedup(_ articles: [TVArticle], limit: Int) -> [TVArticle] {
        var kept: [TVArticle] = []
        var keptTokens: [Set<String>] = []
        for article in articles {
            let t = tokens(article.title + " " + article.summary)
            let duplicate = keptTokens.contains { similarity($0, t) >= 0.5 }
            if duplicate { continue }
            kept.append(article)
            keptTokens.append(t)
            if kept.count >= limit { break }
        }
        return kept
    }

    private static func tokens(_ text: String) -> Set<String> {
        let normalized = text.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let parts = normalized.split { !$0.isLetter && !$0.isNumber }
        return Set(parts.map(String.init).filter { $0.count >= 4 })
    }

    private static func similarity(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let inter = a.intersection(b).count
        guard inter >= 2 else { return 0 }
        let union = a.union(b).count
        return union > 0 ? Double(inter) / Double(union) : 0
    }
}
