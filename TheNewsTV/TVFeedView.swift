import SwiftUI
import SwiftData

/// Pousse soit le Briefing, soit l'agrégat des rubriques abonnées (« Tous les
/// articles »), soit une seule rubrique. Les trois passent par la même
/// navigation **par valeur** (`navigationDestination(for:)`) — mélanger un
/// `NavigationLink(destination:)` classique pour le Briefing avec les autres
/// liens par valeur cassait la résolution de `navigationDestination(for:
/// TVArticleSelection.self)` une fois dedans (ouvrir un article y refermait
/// aussitôt l'écran, un bug propre à tvOS/NavigationStack absent des écrans
/// atteints par valeur).
private enum TVFeedSelection: Hashable {
    case briefing
    case all
    case feed(String)   // Feed.id
}

/// Ligne icône + nom d'une rubrique, avec un espacement généreux entre les
/// deux (le `Label` par défaut est trop serré pour une lecture à distance).
private struct TVFeedRow: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 22) {
            Image(systemName: symbol)
                .frame(width: 32)
            Text(title)
        }
    }
}

/// Écran racine tvOS : Briefing + Tous les articles en tête, puis les rubriques
/// **abonnées** groupées par source. Depuis la Phase E2, la liste des rubriques
/// affichées reflète les vrais abonnements synchronisés via iCloud (mêmes
/// `FeedSubscription` que macOS/iOS) — plus tout le catalogue intégré comme en
/// E1.
struct TVFeedView: View {
    let container: ModelContainer

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FeedSubscription.subscribedAt) private var subscriptions: [FeedSubscription]
    @State private var briefingArticles: [Article] = []

    private var subscribedBySource: [(source: Source, feeds: [Feed])] {
        let ids = Set(subscriptions.map(\.feedID))
        return Feed.bySource
            .map { (source: $0.source, feeds: $0.feeds.filter { ids.contains($0.id) }) }
            .filter { !$0.feeds.isEmpty }
    }

    private var subscribedFeedIDs: [String] {
        let ids = Set(subscriptions.map(\.feedID))
        return Feed.catalog.map(\.id).filter { ids.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !briefingArticles.isEmpty {
                    Section {
                        TVBriefingHeroView(articles: briefingArticles)
                    }
                }
                Section {
                    NavigationLink(value: TVFeedSelection.briefing) {
                        TVFeedRow(title: "Briefing", symbol: "sun.max")
                    }
                    NavigationLink(value: TVFeedSelection.all) {
                        TVFeedRow(title: "Tous les articles", symbol: "tray.full")
                    }
                }
                ForEach(subscribedBySource, id: \.source.id) { group in
                    Section(group.source.name) {
                        ForEach(group.feeds) { feed in
                            NavigationLink(value: TVFeedSelection.feed(feed.id)) {
                                TVFeedRow(title: feed.title, symbol: feed.symbol)
                            }
                        }
                    }
                }
                if subscribedBySource.isEmpty {
                    Section {
                        Text("Aucune rubrique abonnée. Abonnez-vous depuis TheNews sur Mac ou iPhone — la synchronisation iCloud les affichera ici.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("TheNews")
            .navigationDestination(for: TVFeedSelection.self) { selection in
                switch selection {
                case .briefing:
                    TVBriefingView(container: container)
                case .all:
                    TVArticleListView(title: "Tous les articles", feedIDs: subscribedFeedIDs, container: container)
                case .feed(let id):
                    TVArticleListView(title: Feed.byID(id)?.title ?? "", feedIDs: [id], container: container)
                }
            }
            .navigationDestination(for: TVArticleSelection.self) { selection in
                TVArticleDetailView(selection: selection)
            }
            .task { await loadBriefing() }
        }
    }

    private func loadBriefing() async {
        await TVRefreshEngine.run(container: container)
        briefingArticles = BriefingEngine.today(context: modelContext)
    }
}
