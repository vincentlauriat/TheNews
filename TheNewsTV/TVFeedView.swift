import SwiftUI

/// Pousse soit le Briefing, soit l'agrégat de tout le catalogue (« Tous les
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
    case feed(Feed)
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
/// groupées par source (réutilise `Feed.bySource`, le même catalogue que la
/// sidebar macOS/iOS). La TV a la place d'exposer tout le catalogue,
/// contrairement à la Watch qui se limite à 2 flux phares.
struct TVFeedView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(value: TVFeedSelection.briefing) {
                        TVFeedRow(title: "Briefing", symbol: "sun.max")
                    }
                    NavigationLink(value: TVFeedSelection.all) {
                        TVFeedRow(title: "Tous les articles", symbol: "tray.full")
                    }
                }
                ForEach(Feed.bySource, id: \.source.id) { group in
                    Section(group.source.name) {
                        ForEach(group.feeds) { feed in
                            NavigationLink(value: TVFeedSelection.feed(feed)) {
                                TVFeedRow(title: feed.title, symbol: feed.symbol)
                            }
                        }
                    }
                }
            }
            .navigationTitle("TheNews")
            .navigationDestination(for: TVFeedSelection.self) { selection in
                switch selection {
                case .briefing:
                    TVBriefingView()
                case .all:
                    TVArticleListView(title: "Tous les articles", feeds: Feed.builtInCatalog)
                case .feed(let feed):
                    TVArticleListView(title: feed.title, feeds: [feed])
                }
            }
            .navigationDestination(for: TVArticleSelection.self) { selection in
                TVArticleDetailView(selection: selection)
            }
        }
    }
}
