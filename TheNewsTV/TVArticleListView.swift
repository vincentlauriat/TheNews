import SwiftUI

/// Liste des articles d'une rubrique, récupérée en direct (pas de cache
/// persistant). Sélectionner un article pousse son détail.
struct TVArticleListView: View {
    let feed: Feed

    @State private var articles: [ParsedArticle] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if loading && articles.isEmpty {
                ProgressView("Chargement…")
            } else if let errorMessage, articles.isEmpty {
                ContentUnavailableView("Flux indisponible", systemImage: "wifi.slash",
                                       description: Text(errorMessage))
            } else if articles.isEmpty {
                ContentUnavailableView("Aucun article", systemImage: "tray")
            } else {
                List(articles, id: \.id) { article in
                    NavigationLink(value: article) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(article.title).font(.headline)
                            if !article.summary.isEmpty {
                                Text(article.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle(feed.title)
        .navigationDestination(for: ParsedArticle.self) { article in
            TVArticleDetailView(article: article, sourceName: feed.source?.name ?? "")
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            articles = try await RSSService().fetch(feed)
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}
