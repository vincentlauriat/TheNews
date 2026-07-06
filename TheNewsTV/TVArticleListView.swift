import SwiftUI

/// Liste des articles d'une ou plusieurs rubriques (rubrique unique, ou tout le
/// catalogue pour « Tous les articles »), récupérée en direct — pas de cache
/// persistant. Sélectionner un article pousse son détail.
struct TVArticleListView: View {
    let title: String
    let feeds: [Feed]

    @State private var articles: [TVArticle] = []
    @State private var loading = true
    @State private var errorMessage: String?

    /// Borne le nombre d'articles affichés quand plusieurs flux sont agrégés
    /// (évite une liste démesurée sur « Tous les articles »).
    private static let displayLimit = 80

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
                List(Array(articles.enumerated()), id: \.element.id) { index, article in
                    NavigationLink(value: TVArticleSelection(articles: articles, index: index)) {
                        TVArticleRow(article: article)
                    }
                }
            }
        }
        .navigationTitle(title)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        let fetched = await TVArticle.fetch(from: feeds)
        articles = Array(fetched.prefix(Self.displayLimit))
        if articles.isEmpty { errorMessage = "Impossible de charger le(s) flux." }
        loading = false
    }
}
