import SwiftUI

/// Un article réduit pour l'affichage montre (titre + source).
struct WatchArticle: Identifiable, Hashable {
    let id: String
    let title: String
    let source: String
    let link: URL
    let publishedAt: Date
}

/// Vue rapide watchOS : télécharge en direct les gros titres des flux phares de
/// chaque source (Le Monde « À la une », Les Echos « Économie ») et les affiche,
/// triés du plus récent au plus ancien. Autonome — ne dépend pas de l'iPhone.
struct WatchFeedView: View {
    @State private var articles: [WatchArticle] = []
    @State private var loading = true

    /// Flux affichés sur la montre (les « unes » de chaque journal).
    private var feeds: [Feed] {
        ["lemonde.une", "lesechos.economie"].compactMap(Feed.byID)
    }

    var body: some View {
        NavigationStack {
            List {
                if loading && articles.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Chargement…").foregroundStyle(.secondary)
                    }
                } else if articles.isEmpty {
                    Text("Aucun article").foregroundStyle(.secondary)
                } else {
                    ForEach(articles) { article in
                        Link(destination: article.link) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(article.source.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.tint)
                                Text(article.title)
                                    .font(.footnote)
                                    .lineLimit(4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("TheNews")
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        let service = RSSService()
        let scoped = feeds
        var collected: [WatchArticle] = []
        await withTaskGroup(of: [WatchArticle].self) { group in
            for feed in scoped {
                group.addTask {
                    let parsed = (try? await service.fetch(feed)) ?? []
                    let source = feed.source?.name ?? "TheNews"
                    return parsed.map {
                        WatchArticle(id: $0.id, title: $0.title, source: source,
                                     link: $0.link, publishedAt: $0.publishedAt)
                    }
                }
            }
            for await batch in group { collected += batch }
        }
        articles = Array(collected.sorted { $0.publishedAt > $1.publishedAt }.prefix(25))
        loading = false
    }
}
