import SwiftUI
import SwiftData

/// Liste des articles d'une ou plusieurs rubriques abonnées : lit le cache
/// SwiftData local (partagé iCloud avec macOS/iOS), puis déclenche un
/// rafraîchissement réseau qui réinsère les nouveautés dans ce même cache.
struct TVArticleListView: View {
    let title: String
    let feedIDs: [String]
    let container: ModelContainer

    @Environment(\.modelContext) private var modelContext
    @State private var articles: [Article] = []
    @State private var loading = true

    /// Borne le nombre d'articles affichés quand plusieurs flux sont agrégés
    /// (évite une liste démesurée sur « Tous les articles »).
    private static let displayLimit = 80

    var body: some View {
        Group {
            if loading && articles.isEmpty {
                ProgressView("Chargement…")
            } else if articles.isEmpty {
                ContentUnavailableView("Aucun article", systemImage: "tray")
            } else {
                List(Array(articles.enumerated()), id: \.element.id) { index, article in
                    NavigationLink(value: TVArticleSelection(articleIDs: articles.map(\.id), index: index)) {
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
        reload()
        await TVRefreshEngine.run(container: container)
        reload()
        loading = false
    }

    private func reload() {
        let store = FeedStore(context: modelContext)
        articles = Array(((try? store.articles(feedIDs: feedIDs)) ?? []).prefix(Self.displayLimit))
    }
}
