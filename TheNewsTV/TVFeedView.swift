import SwiftUI

/// Pousse soit l'agrégat de tout le catalogue (« Tous les articles »), soit une
/// seule rubrique — les deux affichés par la même `TVArticleListView`.
private enum TVFeedSelection: Hashable {
    case all
    case feed(Feed)
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
                    NavigationLink {
                        TVBriefingView()
                    } label: {
                        Label("Briefing", systemImage: "sun.max")
                    }
                    NavigationLink(value: TVFeedSelection.all) {
                        Label("Tous les articles", systemImage: "tray.full")
                    }
                }
                ForEach(Feed.bySource, id: \.source.id) { group in
                    Section(group.source.name) {
                        ForEach(group.feeds) { feed in
                            NavigationLink(value: TVFeedSelection.feed(feed)) {
                                Label(feed.title, systemImage: feed.symbol)
                            }
                        }
                    }
                }
            }
            .navigationTitle("TheNews")
            .navigationDestination(for: TVFeedSelection.self) { selection in
                switch selection {
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
