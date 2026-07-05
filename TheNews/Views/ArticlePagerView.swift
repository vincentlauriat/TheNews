import SwiftUI

#if os(iOS)
/// Détail d'article paginé (iOS) : on passe d'un article à l'autre en swipant
/// horizontalement. Chaque page est un `ArticleDetailView`. Deux modes de swipe
/// (tous / non lus) via `settings.swipeMode`. Sur macOS, `ContentView` affiche
/// directement le détail.
struct ArticlePagerView: View {
    @Environment(AppSettings.self) private var settings
    @Bindable var vm: FeedViewModel

    /// Séquence de pages **figée** pendant la navigation : recalculée seulement au
    /// changement de mode, ou quand on ouvre un article hors de la séquence — jamais
    /// en plein geste. Sans ce gel, le mode « non lu » retirerait l'article courant
    /// (qui vient d'être marqué lu) au milieu du swipe et casserait le `TabView`
    /// (retour au même article, demi-page).
    @State private var pages: [Article] = []

    var body: some View {
        TabView(selection: selectionBinding) {
            ForEach(pages) { article in
                ArticleDetailView(article: article)
                    .tag(article.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if pages.isEmpty { rebuild() } }
        .onChange(of: settings.swipeMode) { _, _ in rebuild() }
        .onChange(of: vm.selectedArticle?.id) { _, id in
            // Recalcule uniquement si la sélection sort de la séquence figée
            // (ouverture d'un autre article depuis la liste) — pas à chaque swipe.
            if let id, !pages.contains(where: { $0.id == id }) { rebuild() }
        }
    }

    private func rebuild() {
        pages = vm.pagerSequence(mode: settings.swipeMode)
    }

    /// Lie la page visible à l'article sélectionné du ViewModel (et le marque lu).
    private var selectionBinding: Binding<String> {
        Binding(
            get: { vm.selectedArticle?.id ?? "" },
            set: { id in
                if let article = pages.first(where: { $0.id == id }) {
                    vm.select(article)
                }
            }
        )
    }
}
#endif
