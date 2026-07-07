import SwiftUI
import SwiftData

/// Briefing du jour : depuis la Phase E2, réutilise directement `BriefingEngine`
/// (le même que macOS/iOS) sur les rubriques réellement abonnées — plus de
/// réimplémentation « lite » locale (tokens/Jaccard dupliqués), qui existait
/// en E1 faute de SwiftData sur cette cible.
struct TVBriefingView: View {
    let container: ModelContainer

    @Environment(\.modelContext) private var modelContext
    @State private var articles: [Article] = []
    @State private var loading = true

    var body: some View {
        Group {
            if loading && articles.isEmpty {
                ProgressView("Chargement…")
            } else if articles.isEmpty {
                ContentUnavailableView(
                    "Aucun article",
                    systemImage: "tray",
                    description: Text("Abonnez-vous à des rubriques depuis TheNews sur Mac ou iPhone pour voir un briefing ici.")
                )
            } else {
                List(Array(articles.enumerated()), id: \.element.id) { index, article in
                    NavigationLink(value: TVArticleSelection(articleIDs: articles.map(\.id), index: index)) {
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
        await TVRefreshEngine.run(container: container)
        articles = BriefingEngine.today(context: modelContext)
        loading = false
    }
}
