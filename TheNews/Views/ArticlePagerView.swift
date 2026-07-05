import SwiftUI

#if os(iOS)
/// Détail d'article paginé (iOS) : on passe d'un article à l'autre en swipant
/// horizontalement, dans l'ordre de la liste courante. Chaque page est un
/// `ArticleDetailView`. Sur macOS, `ContentView` affiche directement le détail.
struct ArticlePagerView: View {
    @Environment(AppSettings.self) private var settings
    @Bindable var vm: FeedViewModel

    /// Séquence de pages selon le mode de swipe choisi (tous / non lus).
    private var sequence: [Article] { vm.pagerSequence(mode: settings.swipeMode) }

    var body: some View {
        TabView(selection: selectionBinding) {
            ForEach(sequence) { article in
                ArticleDetailView(article: article)
                    .tag(article.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Lie la page visible à l'article sélectionné du ViewModel (et le marque lu).
    private var selectionBinding: Binding<String> {
        Binding(
            get: { vm.selectedArticle?.id ?? "" },
            set: { id in
                if let article = sequence.first(where: { $0.id == id }) {
                    vm.select(article)
                }
            }
        )
    }
}
#endif
