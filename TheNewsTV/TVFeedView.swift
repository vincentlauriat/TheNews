import SwiftUI

/// Écran racine tvOS : rubriques groupées par source (réutilise `Feed.bySource`,
/// le même catalogue que la sidebar macOS/iOS). Sélectionner une rubrique pousse
/// la liste de ses articles ; la TV a la place d'exposer tout le catalogue,
/// contrairement à la Watch qui se limite à 2 flux phares.
struct TVFeedView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(Feed.bySource, id: \.source.id) { group in
                    Section(group.source.name) {
                        ForEach(group.feeds) { feed in
                            NavigationLink(value: feed) {
                                Label(feed.title, systemImage: feed.symbol)
                            }
                        }
                    }
                }
            }
            .navigationTitle("TheNews")
            .navigationDestination(for: Feed.self) { feed in
                TVArticleListView(feed: feed)
            }
        }
    }
}
