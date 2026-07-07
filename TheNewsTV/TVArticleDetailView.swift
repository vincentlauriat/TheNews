import SwiftUI
import SwiftData

/// Sélection d'un article dans une liste donnée — porte les **identifiants**
/// (pas les objets `Article` SwiftData eux-mêmes, pour rester une value-type
/// `Hashable` simple dans la navigation par valeur, comme la sélection par id
/// déjà utilisée côté macOS/iOS) et l'index courant, pour permettre le passage
/// au suivant/précédent en détail (flèches gauche/droite de la télécommande),
/// sans re-fetch de liste ni re-navigation.
struct TVArticleSelection: Hashable {
    let articleIDs: [String]
    var index: Int
}

/// Détail d'un article sur grand écran : image, titre, chapô, source, date.
/// Les flèches gauche/droite de la télécommande passent à l'article
/// précédent/suivant dans la liste d'origine, sans repousser d'écran.
/// Pas de lien « ouvrir dans Safari » — lecture 10 pieds, on affiche le contenu
/// texte déjà présent dans le flux RSS plutôt que de renvoyer vers un navigateur.
struct TVArticleDetailView: View {
    @State private var selection: TVArticleSelection
    @Environment(\.modelContext) private var modelContext
    @State private var article: Article?

    init(selection: TVArticleSelection) {
        _selection = State(initialValue: selection)
    }

    private var currentID: String { selection.articleIDs[selection.index] }

    var body: some View {
        ScrollView {
            if let article {
                VStack(alignment: .leading, spacing: 24) {
                    if let imageURL = article.imageURL {
                        AsyncImage(url: imageURL) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(16.0 / 9.0, contentMode: .fill)
                            } else {
                                Rectangle().fill(.secondary.opacity(0.2))
                                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                            }
                        }
                        .frame(maxHeight: 480)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        // Bloc focusable indépendant : voir la note plus bas.
                        .focusable()
                        .focusEffectDisabled()
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text((article.feed?.source?.name ?? "").uppercased())
                            .font(.caption).bold()
                            .foregroundStyle(.tint)

                        Text(article.title)
                            .font(.largeTitle).bold()

                        if !article.summary.isEmpty {
                            Text(article.summary)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .focusable()
                    .focusEffectDisabled()

                    HStack {
                        Text(article.publishedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if selection.articleIDs.count > 1 {
                            Text("\(selection.index + 1) / \(selection.articleIDs.count) · ◀ ▶")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .focusable()
                    .focusEffectDisabled()
                }
                .padding(.top, 14)
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        // Anime le contenu au changement d'article pour rendre le passage
        // suivant/précédent lisible malgré l'absence de transition de scène.
        .id(currentID)
        // Charge l'article courant et le marque « lu » (persisté SwiftData,
        // synchronisé iCloud) après un court délai. Le faire de façon synchrone
        // dans `onAppear`, pendant l'animation de poussée d'écran, faisait
        // rebondir immédiatement vers la liste sur tvOS — un piège propre à
        // tvOS/NavigationStack indépendant de la source des données (déjà vrai
        // en E1 avec `TVReadStore`, reste vrai en E2 avec `Article.isRead`).
        // `.task(id:)` + délai laisse la transition se terminer avant de
        // toucher l'état observé par l'écran-liste encore vivant en dessous.
        .task(id: currentID) {
            let fetched = fetchArticle(id: currentID)
            article = fetched
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let fetched, !fetched.isRead else { return }
            fetched.isRead = true
            try? modelContext.save()
        }
        // Le scroll tvOS est piloté par le focus (comme une List) : un unique bloc
        // focusable pour tout l'écran fait que haut/bas n'ont rien « en dessous »
        // vers quoi déplacer le focus, donc tombent (comme gauche/droite) dans
        // onMoveCommand, qui ne gérait que gauche/droite → haut/bas ne faisaient
        // rien. En donnant 3 blocs focusables (image/texte/pied), le focus engine
        // déplace nativement le focus haut/bas entre eux (et fait défiler la
        // ScrollView pour le garder visible) ; gauche/droite, qu'aucun bloc ne
        // gère (ils sont empilés verticalement), remonte jusqu'ici. Effet visuel
        // de focus désactivé sur chaque bloc : ce ne sont pas des boutons.
        .onMoveCommand { direction in
            switch direction {
            case .right where selection.index < selection.articleIDs.count - 1:
                selection.index += 1
            case .left where selection.index > 0:
                selection.index -= 1
            default:
                break
            }
        }
    }

    private func fetchArticle(id: String) -> Article? {
        try? modelContext.fetch(FetchDescriptor<Article>(predicate: #Predicate { $0.id == id })).first
    }
}
